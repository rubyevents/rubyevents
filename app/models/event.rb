# == Schema Information
#
# Table name: events
# Database name: primary
#
#  id              :integer          not null, primary key
#  city            :string
#  country_code    :string
#  date            :date
#  date_precision  :string           default("day"), not null
#  end_date        :date
#  kind            :string           default("event"), not null, indexed
#  latitude        :decimal(10, 6)
#  longitude       :decimal(10, 6)
#  name            :string           default(""), not null, indexed
#  slug            :string           default(""), not null, indexed
#  start_date      :date
#  talks_count     :integer          default(0), not null
#  website         :string           default("")
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  canonical_id    :integer          indexed
#  event_series_id :integer          not null, indexed
#
# Indexes
#
#  index_events_on_canonical_id     (canonical_id)
#  index_events_on_event_series_id  (event_series_id)
#  index_events_on_kind             (kind)
#  index_events_on_name             (name)
#  index_events_on_slug             (slug)
#
# Foreign Keys
#
#  canonical_id     (canonical_id => events.id)
#  event_series_id  (event_series_id => event_series.id)
#
class Event < ApplicationRecord
  include Suggestable
  include Sluggable

  configure_slug(attribute: :name, auto_suffix_on_collision: false)

  # associations
  belongs_to :series, class_name: "EventSeries", foreign_key: :event_series_id, strict_loading: false
  has_many :talks, dependent: :destroy, inverse_of: :event, foreign_key: :event_id
  has_many :watchable_talks, -> { watchable }, class_name: "Talk"
  has_many :speakers, -> { distinct }, through: :talks, class_name: "User"
  has_many :keynote_speakers, -> { joins(:talks).where(talks: {kind: "keynote"}).distinct },
    through: :talks, source: :speakers
  has_many :topics, -> { distinct }, through: :talks
  has_many :sponsors, dependent: :destroy
  has_many :organizations, through: :sponsors
  belongs_to :canonical, class_name: "Event", optional: true
  has_many :aliases, class_name: "Event", foreign_key: "canonical_id"
  has_many :slug_aliases, as: :aliasable, class_name: "Alias", dependent: :destroy
  has_many :cfps, dependent: :destroy

  # Event participation associations
  has_many :event_participations, dependent: :destroy
  has_many :participants, through: :event_participations, source: :user
  has_many :speaker_participants, -> { where(event_participations: {attended_as: :speaker}) },
    through: :event_participations, source: :user
  has_many :keynote_speaker_participants, -> { where(event_participations: {attended_as: :keynote_speaker}) },
    through: :event_participations, source: :user
  has_many :visitor_participants, -> { where(event_participations: {attended_as: :visitor}) },
    through: :event_participations, source: :user

  has_many :event_involvements, dependent: :destroy
  has_many :involved_users, -> { where(event_involvements: {involvementable_type: "User"}) },
    through: :event_involvements, source: :involvementable, source_type: "User"
  has_many :involved_event_series, -> { where(event_involvements: {involvementable_type: "EventSeries"}) },
    through: :event_involvements, source: :involvementable, source_type: "EventSeries"

  has_object :schedule
  has_object :static_metadata
  has_object :sponsors_file
  has_object :cfp_file
  has_object :venue

  def talks_in_running_order(child_talks: true)
    talks.in_order_of(:static_id, video_ids_in_running_order(child_talks: child_talks))
  end

  # validations
  validates :name, presence: true
  validates :kind, presence: true
  VALID_COUNTRY_CODES = ISO3166::Country.codes
  validates :country_code, inclusion: {in: VALID_COUNTRY_CODES}, allow_nil: true
  validates :canonical, exclusion: {in: ->(event) { [event] }, message: "can't be itself"}
  validates :date_precision, presence: true

  # scopes
  scope :without_talks, -> { where.missing(:talks) }
  scope :with_talks, -> { where.associated(:talks) }
  scope :with_watchable_talks, -> { where.associated(:watchable_talks) }
  scope :canonical, -> { where(canonical_id: nil) }
  scope :not_canonical, -> { where.not(canonical_id: nil) }
  scope :ft_search, ->(query) {
    joins(<<~SQL.squish)
      LEFT OUTER JOIN aliases AS event_aliases
        ON event_aliases.aliasable_type = 'Event'
        AND event_aliases.aliasable_id = events.id
    SQL
      .joins("LEFT OUTER JOIN event_series AS search_series ON search_series.id = events.event_series_id")
      .joins(<<~SQL.squish)
        LEFT OUTER JOIN aliases AS series_aliases
          ON series_aliases.aliasable_type = 'EventSeries'
          AND series_aliases.aliasable_id = search_series.id
      SQL
      .where(
        "lower(events.name) LIKE :query OR lower(event_aliases.name) LIKE :query " \
        "OR lower(search_series.name) LIKE :query OR lower(series_aliases.name) LIKE :query",
        query: "%#{query.downcase}%"
      )
      .distinct
  }
  scope :past, -> { where(end_date: ..Date.today).order(end_date: :desc) }
  scope :upcoming, -> { where(start_date: Date.today..).order(start_date: :asc) }

  def self.find_by_name_or_alias(name)
    return nil if name.blank?

    event = find_by(name: name)
    return event if event

    alias_record = Alias.find_by(aliasable_type: "Event", name: name)
    alias_record&.aliasable
  end

  def self.find_by_slug_or_alias(slug)
    return nil if slug.blank?

    event = find_by(slug: slug)
    return event if event

    alias_record = Alias.find_by(aliasable_type: "Event", slug: slug)
    alias_record&.aliasable
  end

  def sync_aliases_from_list(alias_names)
    Array.wrap(alias_names).each do |alias_name|
      slug = alias_name.parameterize

      existing_own = slug_aliases.find_by(name: alias_name) || slug_aliases.find_by(slug: slug)

      if existing_own
        existing_own.update(name: alias_name) if existing_own.name != alias_name
        next
      end

      existing_global = Alias.find_by(aliasable_type: "Event", name: alias_name)
      existing_global ||= Alias.find_by(aliasable_type: "Event", slug: slug)

      next if existing_global

      slug_aliases.create!(name: alias_name, slug: slug)
    end
  end

  attribute :kind, :string
  attribute :date_precision, :string

  # enums
  enum :kind, ["event", "conference", "meetup", "retreat", "hackathon", "workshop"].index_by(&:itself), default: "event"
  enum :date_precision, ["day", "month", "year"].index_by(&:itself), default: "day"

  def assign_canonical_event!(canonical_event:)
    ActiveRecord::Base.transaction do
      self.canonical = canonical_event
      save!

      talks.update_all(event_id: canonical_event.id)
      Event.reset_counters(canonical_event.id, :talks)
    end
  end

  def managed_by?(user)
    Current.user&.admin?
  end

  def data_folder
    Rails.root.join("data", series.slug, slug)
  end

  def videos_file?
    videos_file_path.exist?
  end

  def videos_file_path
    data_folder.join("videos.yml")
  end

  def videos_file
    return [] unless videos_file?

    YAML.load_file(videos_file_path)
  end

  def video_ids_in_running_order(child_talks: true)
    return [] unless videos_file?

    if child_talks
      videos_file.flat_map { |talk|
        [talk.dig("id"), *talk["talks"]&.map { |child_talk|
          child_talk.dig("id")
        }]
      }
    else
      videos_file.map { |talk| talk.dig("id") }
    end
  end

  def suggestion_summary
    <<~HEREDOC
      Event: #{name}
      #{description}
      #{city}
      #{country_code}
      #{series.name}
      #{date}
    HEREDOC
  end

  def today?
    (start_date..end_date).cover?(Date.today)
  rescue => _e
    false
  end

  def formatted_dates
    case date_precision
    when "year"
      start_date.strftime("%Y")
    when "month"
      start_date.strftime("%B %Y")
    when "day"
      return I18n.l(start_date, default: "unknown") if start_date == end_date

      if start_date.strftime("%Y-%m") == end_date.strftime("%Y-%m")
        return "#{start_date.strftime("%B %d")}-#{end_date.strftime("%d, %Y")}"
      end

      if start_date.strftime("%Y") == end_date.strftime("%Y")
        return "#{I18n.l(start_date, format: :month_day, default: "unknown")} - #{I18n.l(end_date, default: "unknown")}"
      end

      "#{I18n.l(start_date, format: :medium,
        default: "unknown")} - #{I18n.l(end_date, format: :medium, default: "unknown")}"
    end
  end

  def country
    return nil if country_code.blank?

    ISO3166::Country.new(country_code)
  end

  def coordinates
    [longitude, latitude]
  end

  def country_name
    return nil if country_code.blank?

    ISO3166::Country.new(country_code)&.translations&.[]("en")
  end

  def country_url
    Router.country_path(static_metadata.country&.translations&.[]("en")&.parameterize)
  rescue
    Router.countries_path
  end

  def held_in_sentence
    return "" if country_name.blank?

    if country_name.starts_with?("United")
      %( held in the #{country_name})
    else
      %( held in #{country_name})
    end
  end

  def description
    return @description if @description.present?

    event_name = series.organisation? ? name : series.name

    @description = <<~DESCRIPTION
      #{event_name} is a #{static_metadata.frequency} #{kind}#{held_in_sentence}#{talks_text}#{keynote_speakers_text}.
    DESCRIPTION
  end

  def keynote_speakers_text
    keynote_speakers.size.positive? ? %(, including keynotes by #{keynote_speakers.map(&:name).to_sentence}) : ""
  end

  def talks_text
    talks.size.positive? ? " and features #{talks.size} #{"talk".pluralize(talks.size)} from various speakers" : ""
  end

  def to_meta_tags
    {
      title: name,
      description: description,
      og: {
        title: name,
        type: :website,
        image: {
          _: Router.image_path(card_image_path),
          alt: name
        },
        description: description,
        site_name: "RubyEvents.org"
      },
      twitter: {
        card: "summary_large_image",
        site: "@rubyevents_org",
        title: name,
        description: description,
        image: {
          src: Router.image_path(card_image_path)
        }
      }
    }
  end

  def event_image_path
    ["events", series.slug, slug].join("/")
  end

  def default_event_image_path
    ["events", "default"].join("/")
  end

  def default_event_series_image_path
    ["events", series.slug, "default"].join("/")
  end

  def event_image_or_default_for(filename)
    event_path = [event_image_path, filename].join("/")
    default_event_series_path = [default_event_series_image_path, filename].join("/")
    default_path = [default_event_image_path, filename].join("/")

    base = Rails.root.join("app", "assets", "images")

    return event_path if (base / event_path).exist?
    return default_event_series_path if (base / default_event_series_path).exist?

    default_path
  end

  def event_image_for(filename)
    event_path = [event_image_path, filename].join("/")

    Rails.root.join("app", "assets", "images", event_image_path, filename).exist? ? event_path : nil
  end

  # banner - 1300x350
  def banner_image_path
    event_image_or_default_for("banner.webp")
  end

  # card - 600x350
  def card_image_path
    event_image_or_default_for("card.webp")
  end

  # avatar - 256x256
  def avatar_image_path
    event_image_or_default_for("avatar.webp")
  end

  # featured - 615x350
  def featured_image_path
    event_image_or_default_for("featured.webp")
  end

  # poster - 600x350
  def poster_image_path
    event_image_or_default_for("poster.webp")
  end

  def stickers
    Sticker.for_event(self)
  end

  # sticker - 350x350
  def sticker_image_paths
    stickers.map(&:file_path)
  end

  def sticker_image_path
    sticker_image_paths.first
  end

  def stamp_image_paths
    base = Rails.root.join("app", "assets", "images")
    Dir.glob(base.join(event_image_path, "stamp*.webp")).map { |path|
      Pathname.new(path).relative_path_from(base).to_s
    }.sort
  end

  def stamp_image_path
    stamp_image_paths.first
  end

  def sticker?
    sticker_image_paths.any?
  end

  def stamp?
    stamp_image_paths.any?
  end

  def watchable_talks?
    talks.where.not(video_provider: ["scheduled", "not_published", "not_recorded"]).exists?
  end

  def featured_metadata?
    static_metadata.featured_background?
  end

  def featurable?
    featured_metadata? && watchable_talks?
  end

  def website
    self[:website].presence || series.website
  end

  def to_mobile_json(request)
    {
      id: id,
      name: name,
      slug: slug,
      location: static_metadata.location,
      start_date: start_date&.to_s,
      end_date: end_date&.to_s,
      card_image_url: Router.image_path(card_image_path, host: "#{request.protocol}#{request.host}:#{request.port}"),
      featured_image_url: Router.image_path(featured_image_path,
        host: "#{request.protocol}#{request.host}:#{request.port}"),
      featured_background: static_metadata.featured_background,
      featured_color: static_metadata.featured_color,
      url: Router.event_url(self, host: "#{request.protocol}#{request.host}:#{request.port}")
    }
  end
end
