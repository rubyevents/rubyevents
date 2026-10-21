### `Yerba::Record`

**ActiveRecord-like models backed by Yerba YAML documents.**

`Yerba::Record` provides a familiar Ruby API for querying and mutating YAML data files. It sits on top of [Yerba](https://github.com/marcoroth/yerba) and adds records, collections, associations, schemas, indexing, and cross-file references.

Think of it as [`frozen_record`](https://github.com/byroot/frozen_record) but writable, reads are fast, writes go through Yerba (preserving comments, formatting, and structure).

> **Future gem name idea:** `terere`, the cold version of yerba mate.

### Defining a Record

```ruby
class Static::Speaker < Yerba::Record::Base
  self.path = "data/speakers.yml"

  schema SpeakerSchema

  add_index :name, include: "aliases[].name"
  add_index :slug
  add_index :github
end
```

`path` is relative to `root` (`Yerba::Record::Base.root = Rails.root`, set in `config/initializers/static_models.rb`). Like a route, it can name its segments, and the model then loads every file that matches, one record per file:

```ruby
class Static::Event < Yerba::Record::Base
  self.path = "data/:series_id/:id/event.yml"

  schema EventSchema

  belongs_to :series, class_name: "Static::EventSeries"
  has_many :talks, class_name: "Static::Talk"
  has_many :cfps, class_name: "Static::CFP"
  has_one :venue
  has_one :schedule
end

event.path_params  # => {series_id: "rubyconf", id: "rubyconf-2024"}
```

For files that each contain an array of records:

```ruby
class Static::Talk < Yerba::Record::Base
  self.path = "data/:series_id/:event_id/videos.yml"
  self.flatten = true

  schema VideoSchema

  belongs_to :event, class_name: "Static::Event"
  has_one :series, through: :event
  references :speakers
end
```

For scalar arrays (e.g., topics.yml is a list of strings):

```ruby
class Static::Topic < Yerba::Record::Base
  self.path = "data/topics.yml"
  self.scalar_field = "name"

  schema do
    string :name, description: "Topic name", required: true
  end
end
```

`file_path` and `file_glob` return the full path or glob of a model's files, for code that reads them with Yerba directly:

```ruby
Static::Speaker.file_path  # => "/.../data/speakers.yml"
Static::Talk.file_glob     # => "/.../data/**/videos.yml"

Yerba::Collection.get(Static::Talk.file_glob, "[].speakers[]")
```

## Schemas

Schemas define the fields on a record. They reuse `RubyLLM::Schema` and serve triple duty: field definitions, validation on save, and MCP tool parameter generation.

Reference an existing schema class:

```ruby
schema EventSchema
```

Or define inline:

```ruby
schema do
  string :name, required: true
  string :kind, enum: %w[conference meetup]
  string :website, required: false
  array :aliases, of: :string, required: false
end
```

When a schema is set, real methods are defined for each field (no `method_missing`):

```ruby
event.respond_to?(:title)     # => true
event.respond_to?(:fake)      # => false
```

## Validations

Validations work just like they do in ActiveRecord. Records include `ActiveModel::Validations`, so you can use the built-in validators, a validator class, a method, or a block:

```ruby
class Static::Event < Yerba::Record::Base
  validates :start_date, :end_date, presence: true, unless: :meetup?
  validates :end_date, comparison: {greater_than_or_equal_to: :start_date}
  validates :location, "static/city_name": true
  validate :speakers_exist
  validate { errors.add(:base, "needs a website") if self["website"].blank? }
end
```

### On save

Validations run whenever a record is written. `save!` raises `Yerba::Record::RecordInvalid` and leaves the file untouched, `save` returns `false`, and `save!(validate: false)` skips them.

When you save a collection, only the records you built or changed are validated. A problem somewhere else in the same file won't stop you from writing.

### The `:lint` context

Some checks need to look beyond the record: the event's series, every other talk id, the images in an event's folder. Those are slower, and they shouldn't block a write, so they go in the `:lint` context:

```ruby
validates :id, uniqueness: {also: :old_id}, on: :lint
validates :thumbnail, file: {presence: true}, on: :lint
```

Lint validations run when you check the whole dataset with `bin/rails validate:all` (or a single part of it, like `validate:videos`). From Ruby:

```ruby
Yerba::Record.validate_all                              # every record of every model
Yerba::Record.validate_file("data/x/x-2025/videos.yml") # the records of one file, nested ones included
```

As a rule of thumb: if a check only looks at the record itself, it runs on save. If it reads other files, it goes in `:lint`.

### Built-in validators

On top of ActiveModel's validators, there are three that know about YAML files:

- `uniqueness` checks a value against all records of the model. `also: :old_id` makes `id` and `old_id` share one namespace.
- `matches_path` checks that a value matches its folder in the path, like an event's `id`.
- `file` checks the file behind a `has_file`, with `presence:` and `dimensions:`.

File records validate like any other record:

```ruby
class Static::Thumbnail < Yerba::Record::FileRecord
  self.path = "app/assets/images/thumbnails/**/:video_id.webp"

  validate :not_redundant, on: :lint
end
```

### Where errors point

Every error is attached to a Yerba node, so `validate:all` can tell you the file and line. `record.error_location(error)` gives you the location of the attribute's value, or of the record itself when the key is missing. `record.error_file_path(error)` gives you the file.

To point somewhere else, pass `at:`. Use `at: "aliases[0].slug"` for another key, or `at: :file` for the file as a whole.

Messages use the YAML key as the attribute name, so you get `old_id "x" is not unique` rather than `Old is not unique`.

An error added with `severity: :warning` shows up in the report but doesn't block a save.

### Looking at other records

A validator that compares a record with its neighbours can read them with `record.file_records` (the other records in the same file) or `Model.all`.

Working that out for every record would be slow, so wrap it in `Yerba::Record::Validations.cached(key) { ... }`. The cache only lives for one `validate_all` or `fix_all` run. Each file is read once per run, and a single `valid?` call always sees the current data.

### Fixing what's reported

A validator can also repair what it reports. Define `fix(record)` and return the number of changes:

```ruby
class Static::SponsorSlugValidator < ActiveModel::EachValidator
  def fix(sponsor)
    expected = sponsor["name"].parameterize
    return 0 if sponsor["slug"] == expected

    sponsor["slug"] = expected

    1
  end
end
```

`bin/rails validate:fix` runs every fix and saves the records that changed. To run a single one:

```ruby
Yerba::Record.fix_all(Static::Talk.in_file(path), only: Static::TalkIdValidator)
```

## Querying

```ruby
Static::Speaker.count                         # => 4593
Static::Speaker.first.name                    # => "Aaron Patterson"
Static::Speaker.find_by(name: "Matz")         # => indexed O(1) lookup
Static::Speaker.where(github: "tenderlove")   # => Linear search
Static::Speaker.pluck(:name)                  # => ["Aaron Patterson", ...]
```

`find_by` on indexed fields is O(1) via `LazyIndex`; other lookups scan the records. Reads are served from one materialized value tree per document, so iterating thousands of records doesn't call into Yerba per record.

`where` returns a chainable collection (`where.not(...)`, `where(...).where(...)`, `pluck`). An Array, Set or Range value matches like SQL `IN`. Like ActiveRecord, `where.not` with several keys only excludes records that match all of them.

## Collections

`Model.all` (every file of the model), `Model.in_file(path, document: nil)` (one file or parsed document), `Model.parse(yaml)`, path-based `has_many` associations, nested children and `where` results are all a `Yerba::Record::Collection`, spanning one or more documents:

```ruby
Static::Talk.all.count                                    # every talk across every videos.yml, nested ones included
Static::Talk.in_file("data/rubyconf/rubyconf-2024/videos.yml").ids
static_event.talks.find_by(id: "jane-doe-rubyconf-2024")
Static::Talk.all.files.each { |file| file.save! if file.changed? }
```

Like an ActiveRecord relation, a collection runs the model's class methods and scopes over itself. Inside them, `all` is the collection they were called on:

```ruby
class Static::Talk < Yerba::Record::Base
  scope :top_level, -> { where.missing(:parent) }
  scope :youtube, -> { where(video_provider: "youtube") }
  scope :youtube_missing_published_at, -> { youtube.where(published_at: [nil, "", "TODO"]) }

  def self.ids
    all.filter_map(&:id)
  end
end

Static::Talk.ids                 # every videos.yml
static_event.talks.ids           # one videos.yml
static_event.talks.top_level
static_event.talks.youtube_missing_published_at
Static::Talk.where(kind: "keynote").ids
```

Single-file collections can be edited in place (each call saves):

```ruby
talks = static_event.talks
talks.create({id: "keynote", title: "Keynote"}, after: "opening")
talks.reorder(%w[keynote opening closing])
talks.move("closing", to: 0)
talks.destroy("opening")
```

A Yerbafile `sort` rule re-sorts on save. The sort is stable, so a running order persists between talks with the same sort keys.

## Nested records

Records can live inside other records, e.g. the individual `talks:` of a lightning talks block in `videos.yml`. Declare them with `has_many :talks, nested: true`. Nested records are regular records of the same model, addressed by a selector like `"[3].talks[1]"` in the same document. Every collection of the model includes them right after their parent. `where.missing(:parent)` leaves them out, `where.associated(:parent)` keeps only them:

```ruby
class Static::Talk < Yerba::Record::Base
  has_many :talks, nested: true
end

Static::Talk.all.count                        # every talk, nested ones included
Static::Talk.where.missing(:parent).count     # only talks without a parent
Static::Talk.where.associated(:parent).count  # only nested talks

lightning_talks = static_event.talks.find_by(id: "lightning-talks-rubyconf-2024")
lightning_talk = lightning_talks.talks.first
lightning_talk.parent # => lightning_talks

lightning_talk["published_at"] = "2025-01-01T00:00:00Z"
lightning_talk.insert("old_id", "previous-id", after: "id")
lightning_talk.save!

lightning_talks.talks.reorder(lightning_talks.talks.map(&:id).reverse)
```

Nested records can also be of another model. They stay out of the owning model's collections, and the nested model's `all` collects them from every owning record (`Static::Sponsor::Tier.all`):

```ruby
class Static::Sponsor < Yerba::Record::Base
  has_many :tiers, nested: true, class_name: "Static::Sponsor::Tier"
end

class Static::Sponsor::Tier < Yerba::Record::Base
  has_many :sponsors, nested: true, class_name: "Static::Sponsor::Entry"
end

entry = static_event.sponsors.first.tiers.first.sponsors.find_by(slug: "avo")
entry["slug"] = "avo-hq"
entry.save!
```

## Reading

```ruby
speaker = Static::Speaker.find_by(name: "Aaron Patterson")
speaker.name       # => "Aaron Patterson"
speaker.github     # => "tenderlove"
speaker["website"] # => "https://..."
speaker.to_h       # => {"name" => "Aaron Patterson", ...}
speaker.to_yaml    # => original YAML text (preserves formatting)
```

## Writing

Records are directly writable:

```ruby
speaker = Static::Speaker.find_by(name: "Matz")
speaker.website = "https://ruby-lang.org"
speaker.save!  # writes to speakers.yml with Yerbafile rules applied
```

Shortcut:

```ruby
speaker.update(website: "https://ruby-lang.org", twitter: "yukihiro_matz")
```

`set` replaces a value, or inserts the key at a position when it isn't there yet, and can set the quote style of the value:

```ruby
talk.set("published_at", "2024-05-01T10:00:00Z", after: "date", quote_style: :double)
```

## Creating

Build a new record, set fields, and save:

```ruby
series = Static::EventSeries.new(name: "RubyConf", kind: "conference")
series.website = "https://rubyconf.org"
series.save!
```

Or create in one step:

```ruby
Static::EventSeries.create(name: "RubyConf", kind: "conference")
```

Find an existing record or create it:

```ruby
Static::EventSeries.find_or_create_by(name: "RubyConf")
```

New records are validated against the schema before saving.

## Destroying

Removes the record from the array and saves the file:

```ruby
speaker = Static::Speaker.find_by(name: "Old Speaker")
speaker.destroy

speaker.destroyed?  # => true
speaker.name        # => "Old Speaker", the values it had before it was removed
speaker.save!       # => raises FrozenError
```

## Renaming and moving

A record owns the directory at the `:id` segment of its path, like `data/:series_id/:id/` for an event. Every named segment other than `:id` gets an accessor, like `event.series_id`. Saving a changed `id` or segment moves that directory, and the record then reads from its new path:

```ruby
event["id"] = "rubyconf-2025"
event.save!                             # data/rubyconf/rubyconf-2024/ -> data/rubyconf/rubyconf-2025/

event.series_id = "rubyconf"
event.save!                             # data/other/rubyconf-2024/ -> data/rubyconf/rubyconf-2024/

event.rename!("rubyconf-2025")          # assigns the id and saves
event.move_to!(series_id: "rubyconf")   # assigns the segments and saves
series.rename!("ruby-conf")             # data/rubyconf/ -> data/ruby-conf/, with all its events
```

The files and directories a model declares with `has_file` and `has_files` move along (see below).

Nothing moves when a target directory already exists, or when the directory it moves into doesn't exist yet, like the folder of a series that wasn't created. A model can say how to create that record by overriding `missing_parent_message(directory, path_params)`, as `Static::Event` does for its series. Values that only contain the old id, like talk ids ending in the event slug, stay as they are, and `bin/rails validate:fix` renames them afterwards, with their thumbnails.

## Associations

### `belongs_to` (field-based)

Look up a parent record by a field value:

```ruby
class Static::Event < Yerba::Record::Base
  belongs_to :series, class_name: "Static::EventSeries", foreign_key: :series_slug
end
```

```ruby
event.series
```

### `belongs_to` (file-path derived)

When no `foreign_key:` is given, the path of the associated record is built from the path params of this one. The associated model's `:id` is this record's `:<association>_id`, and the other named segments are shared by name. So a talk in `data/rubyconf/rubyconf-2024/videos.yml` belongs to the event in `data/rubyconf/rubyconf-2024/event.yml`:

```ruby
class Static::Talk < Yerba::Record::Base
  self.path = "data/:series_id/:event_id/videos.yml"

  belongs_to :event   # data/:series_id/:id/event.yml
  belongs_to :series  # data/:id/series.yml
end
```

```ruby
talk.event
talk.event_slug  # => "rubyconf-2024", the :event_id path param
```

### `has_many` (query-based)

Filter all records of another model by a field:

```ruby
class Static::EventSeries < Yerba::Record::Base
  has_many :events, foreign_key: :series_slug
end
```

```ruby
series.events
```

### `has_many` (path-based)

Without `foreign_key:` or `nested:`, the records come from the file the associated model's path names for this record. Its `:<model>_id` is this record's `:id`, so an event's talks are in `data/:series_id/:event_id/videos.yml` with the event's id as `:event_id`:

```ruby
class Static::Event < Yerba::Record::Base
  has_many :talks, class_name: "Static::Talk"
  has_many :cfps
end
```

```ruby
event.talks.count
event.talks.find_by(id: "talk-1")
event.talks.create(id: "new-talk", title: "My Talk")
event.talks.save!
```

### `has_one` (path-based)

Load a single record from the file the associated model's path names for this record:

```ruby
class Static::Event < Yerba::Record::Base
  has_one :venue     # data/:series_id/:event_id/venue.yml
  has_one :schedule  # data/:series_id/:event_id/schedule.yml
end
```

```ruby
event.venue.name
event.venue.name = "Updated"
event.venue.save!
```

Build or create an associated record when the file doesn't exist:

```ruby
event.venue                                        # => nil (no venue.yml)
event.build_venue(name: "Convention Center")       # => in-memory, not saved
event.create_venue(name: "Convention Center")      # => creates venue.yml and saves
event.venue                                        # => Static::Venue
```

### `has_one` with `through:` (delegated association)

Delegate to an association on another record:

```ruby
class Static::Talk < Yerba::Record::Base
  belongs_to :event
  has_one :series, through: :event
end
```

```ruby
talk.series
```

A record nested in another model has no file of its own to take the event from, so it goes through its parent:

```ruby
class Static::Talk::AlternativeRecording < Yerba::Record::Base
  has_one :event, through: :parent
  has_one :series, through: :parent
end
```

### `has_file` and `has_files` (files named by the path)

Files and directories named by segments of the record's path, or by its attributes when the path doesn't have the segment. They move when those segments or attributes change and the record is saved, unless a file already exists at the new path:

```ruby
class Static::Event < Yerba::Record::Base
  self.path = "data/:series_id/:id/event.yml"

  has_files :images, "app/assets/images/events/:series_id/:id"
  has_files :thumbnails, "app/assets/images/thumbnails/:id", recursive: true
  has_files :stamps, "app/assets/images/events/:series_id/:id/stamp*.webp"

  has_file :avatar, "app/assets/images/events/:series_id/:id/avatar.webp"
end

class Static::Talk < Yerba::Record::Base
  self.path = "data/:series_id/:event_id/videos.yml"

  has_file :thumbnail, "app/assets/images/thumbnails/:event_id/**/:video_id.webp"   # :video_id is an attribute
  has_files :child_thumbnails, "app/assets/images/thumbnails/:event_id/:id"
end
```

`has_file` returns the `Pathname`, whether the file exists or not. With `**`, it finds the file in any subdirectory, or else returns the path without it:

```ruby
event.avatar.exist?
event.avatar.read
talk.thumbnail                 # => app/assets/images/thumbnails/rubyconf-2024/lightning-talks-rubyconf-2024/jane-doe-rubyconf-2024.webp
```

`has_files` returns a `Yerba::Record::Files`, which lists the files of the directory as `Pathname`s (with `recursive: true` also the files in its subdirectories), or the files matching a wildcard in the last segment:

```ruby
event.stamps.count             # => 3
event.stamps.first             # => #<Pathname app/assets/images/events/euruko/euruko-2025/stamp-1.webp>
event.images.map(&:basename)   # => [avatar.webp, banner.webp, card.webp, ...]
event.images["card.webp"]      # => the Pathname, or nil when there is no such file
event.images.path              # => the directory, whether it exists or not
```

Saving a talk with a changed `video_id` renames its thumbnail, and a changed `id` renames the directory with the thumbnails of its child talks, the same way renaming an event moves its images.

### File records

A model backed by files instead of YAML, like stickers, inherits from `Yerba::Record::FileRecord`. Each file matching its path is a record, and the segments of the path are its attributes:

```ruby
class Static::Sticker < Yerba::Record::FileRecord
  self.path = "app/assets/images/events/:series_id/:event_id/sticker*.webp"

  belongs_to :event
end

class Static::Event < Yerba::Record::Base
  has_many :stickers, class_name: "Static::Sticker"
end
```

```ruby
Static::Sticker.all
Static::Sticker.where(event_id: "rubyconf-2024")
event.stickers                 # the files matching the event's path params
sticker.event                  # the Static::Event in the same folder
sticker.event_id               # => "rubyconf-2024"
sticker.path                   # => Pathname
sticker.event_id = "rubyconf-2025"
sticker.save!                  # moves the file
```

Subclasses with their own paths make a file model polymorphic. The base class lists them in order of precedence with `types`, and a file is the first of them its path matches. `constraints` restrict what a segment matches, like route constraints, and `order_by` sorts `all`:

```ruby
class Static::Stamp < Yerba::Record::FileRecord
  types "Static::CountryStamp", "Static::UKNationStamp", "Static::EventStamp", "Static::AchievementStamp"
  self.order_by = :name

  def owner = nil   # a Country, UKNation or Static::Event in the subclasses
end

class Static::CountryStamp < Static::Stamp
  self.path = "app/assets/images/stamps/:country_code.webp"
  self.constraints = {country_code: /[a-z]{2}/}
end

class Static::AchievementStamp < Static::Stamp
  self.path = "app/assets/images/stamps/:stamp_id.webp"   # the stamps the other types don't match
end
```

```ruby
Static::Stamp.all                  # every stamp, each as its type, sorted by name
Static::AchievementStamp.all       # only the achievement stamps
```

### `references` (cross-file foreign keys)

Declare that a field contains names that reference records in another file. Like `has_many`, the referenced model defaults to the singular field name in the model's namespace (`Static::Speaker` for `Static::Talk`), and `class_name:` takes the full name of another model:

```ruby
class Static::Talk < Yerba::Record::Base
  references :speakers
end
```

Reading resolves to record objects:

```ruby
talk.speakers.first.github
talk.speakers.names
```

Writing appends to the YAML and auto-creates missing records:

```ruby
speaker = talk.speakers << "New Person"
speaker.save!
talk.save!
```

The referenced model knows every declaration made against it, so it can collect the values that reference it, each with its record and the selector of the value. A declaration is registered when its model is loaded, so with lazy loading, load the declaring models first (RubyEvents does this in `config/initializers/static_models.rb`):

```ruby
class Static::Involvement < Yerba::Record::Base
  references :users, class_name: "Static::Speaker"
end

class Static::Talk::AlternativeRecording < Yerba::Record::Base
  references :speakers, class_name: "Static::Speaker"
end

Static::Speaker.inbound_references.each do |reference|
  reference.value          # => "Aaron Patterson"
  reference.record         # => #<Static::Talk ...>, #<Static::Involvement ...> or #<Static::Talk::AlternativeRecording ...>
  reference.file_path      # => ".../data/rubyconf/rubyconf-2024/videos.yml"
  reference.line           # => 42
  reference.selector       # => "speakers[0]", relative to the record
  reference.full_selector  # => "[6].alternative_recordings[0].speakers[0]", in the file
end
```

## Indexing

```ruby
class Static::Speaker < Yerba::Record::Base
  add_index :name, include: "aliases[].name"
  add_index :slug
end

Static::Speaker.find_by(name: "Aaron Patterson")  # => O(1) via LazyIndex
Static::Speaker.find_by(name: "Matz")             # => O(1), matches an alias
Static::Speaker.find_by(twitter: "tenderlove")    # => Linear Scan
```

Indexes are built lazily on first use from the document's parsed values and cached on the collection until `unload!`. Values at the `include:` selector resolve to the record that lists them, and a value of the field itself wins over an included one.

## Raw Yerba Access

```ruby
speaker.node                    # => Yerba::Map (live CST node)
speaker.node["name"]            # => Yerba::Scalar
speaker.node["name"].selector   # => "[42].name"
speaker.node["name"].source     # => '"Aaron Patterson"' (original YAML text)
speaker.node.source             # => full YAML text of the entry

speaker.source_line                    # => 1234, line of the entry
speaker.source_line("github")          # => 1235, line of a value
speaker.source_line("aliases[1].slug") # => 1240, a selector relative to the record
speaker.source_location("name")        # => Yerba::Location (start/end line and column)
```

## Stale File Detection

Yerba tracks file modification times. If a file is modified externally between load and save, `save!` raises `Yerba::StaleFileError`:

```ruby
speaker = Static::Speaker.first
# ... another process edits speakers.yml ...
speaker.save!  # => raises Yerba::StaleFileError
```

## Architecture

```
Yerba::Record::Base                # Record class (read + write + schema)
  include Querying                 # .all, .find_by, .where, .pluck
  include Indexing                 # add_index, LazyIndex
  include References               # references :speakers DSL
  include Associations             # belongs_to, has_many, has_one (path-based, through:), has_files
  include Schema                   # schema, create, field method generation
  include Validations              # ActiveModel validations, run on save and by validate_all

Yerba::Record::Collection          # Records of one or more documents (all, in_file, has_many, nested, where)
Yerba::Record::Collection::Source  # One document, or a nested sequence in it, contributing records
Yerba::Record::ReferencesProxy     # Resolved cross-file references
Yerba::Record::LazyIndex           # value -> position index, resolves records on access
Yerba::Record::PathPattern         # A model's path with named segments, like data/:series_id/:id/event.yml
Yerba::Record::Files              # The files of a has_files directory or wildcard
Yerba::Record::FileRecord         # A record backed by a file, with its path segments as attributes
```
