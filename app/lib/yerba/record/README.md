### `Yerba::Record`

**ActiveRecord-like models backed by Yerba YAML documents.**

`Yerba::Record` provides a familiar Ruby API for querying and mutating YAML data files. It sits on top of [Yerba](https://github.com/marcoroth/yerba) and adds records, collections, associations, schemas, indexing, and cross-file references.

Think of it as [`frozen_record`](https://github.com/byroot/frozen_record) but writable, reads are fast, writes go through Yerba (preserving comments, formatting, and structure).

> **Future gem name idea:** `terere`, the cold version of yerba mate.

### Defining a Record

```ruby
class Static::Speaker < Yerba::Record::Base
  self.path = "speakers.yml"
  self.base_path = Rails.root.join("data")

  schema SpeakerSchema

  add_index :name, include: "aliases[].name"
  add_index :slug
  add_index :github
end
```

For multi-file globs (one record per file):

```ruby
class Static::Event < Yerba::Record::Base
  self.glob = "**/event.yml"
  self.base_path = Rails.root.join("data")

  schema EventSchema

  belongs_to :series, class_name: "Static::EventSeries", foreign_key: :series_slug
  has_many :talks, in_file: "videos.yml", class_name: "Static::Talk"
  has_many :cfps, in_file: "cfp.yml", class_name: "Static::CFP"
  has_one :venue, in_file: "venue.yml", class_name: "Static::Venue"
  has_one :schedule, in_file: "schedule.yml", class_name: "Static::Schedule"
end
```

For multi-file globs where each file contains an array of records:

```ruby
class Static::Talk < Yerba::Record::Base
  self.glob = "**/videos.yml"
  self.base_path = Rails.root.join("data")
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
  self.path = "topics.yml"
  self.base_path = Rails.root.join("data")
  self.scalar_field = "name"

  schema do
    string :name, description: "Topic name", required: true
  end
end
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

## Querying

```ruby
Static::Speaker.count                         # => 4593
Static::Speaker.first.name                    # => "Aaron Patterson"
Static::Speaker.find_by(name: "Matz")         # => indexed O(1) lookup
Static::Speaker.where(github: "tenderlove")   # => Linear search
Static::Speaker.pluck(:name)                  # => ["Aaron Patterson", ...]
```

`find_by` on indexed fields is O(1) via `LazyIndex`; other lookups scan the records. Reads are served from one materialized value tree per document, so iterating thousands of records doesn't call into Yerba per record.

`where` returns a chainable collection (`where.not(...)`, `where(...).where(...)`, `pluck`). An Array, Set or Range value matches like SQL `IN`.

## Collections

`Model.all` (every file of the model), `Model.in_file(path, document: nil)` (one file or parsed document), `Model.parse(yaml)`, `has_many ..., in_file:` associations, nested children and `where` results are all a `Yerba::Record::Collection`, spanning one or more documents:

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

  def self.ids
    all.filter_map(&:id)
  end
end

Static::Talk.ids                 # every videos.yml
static_event.talks.ids           # one videos.yml
static_event.talks.top_level
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

A Yerbafile `sort` rule re-sorts on save (e.g. videos.yml by date and time). The sort is stable, so a running order persists between talks with the same sort keys.

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
```

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

When no `foreign_key:` is given, the parent slug is derived from the directory name:

```ruby
class Static::Talk < Yerba::Record::Base
  belongs_to :event
end
```

```ruby
talk.event
talk.event_slug
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

### `has_many` with `in_file:` (per-directory YAML array)

Load records from an array YAML file in the same directory:

```ruby
class Static::Event < Yerba::Record::Base
  has_many :talks, in_file: "videos.yml", class_name: "Static::Talk"
  has_many :cfps, in_file: "cfp.yml"
end
```

```ruby
event.talks.count
event.talks.find_by(id: "talk-1")
event.talks.create(id: "new-talk", title: "My Talk")
event.talks.save!
```

### `has_one` with `in_file:` (per-directory YAML object)

Load a single record from an object YAML file in the same directory:

```ruby
class Static::Event < Yerba::Record::Base
  has_one :venue, in_file: "venue.yml"
  has_one :schedule, in_file: "schedule.yml"
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

### `references` (cross-file foreign keys)

Declare that a field contains names that reference records in another file:

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
  include Associations             # belongs_to, has_many, has_one (in_file:, through:)
  include Schema                   # schema, create, field method generation

Yerba::Record::Collection          # Records of one or more documents (all, in_file, has_many in_file:, nested, where)
Yerba::Record::Collection::Source  # One document, or a nested sequence in it, contributing records
Yerba::Record::ReferencesProxy     # Resolved cross-file references
Yerba::Record::LazyIndex           # value -> position index, resolves records on access
```
