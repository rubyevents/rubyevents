# == Schema Information
#
# Table name: events
# Database name: primary
#
#  id               :integer          not null, primary key
#  city             :string
#  country_code     :string           indexed => [state_code]
#  date             :date
#  date_precision   :string           default("day"), not null
#  description      :string
#  end_date         :date
#  geocode_metadata :json             not null
#  kind             :string           default("event"), not null, indexed
#  latitude         :decimal(10, 6)
#  location         :string
#  longitude        :decimal(10, 6)
#  name             :string           default(""), not null, indexed
#  slug             :string           default(""), not null, indexed
#  start_date       :date
#  state_code       :string           indexed => [country_code]
#  talks_count      :integer          default(0), not null
#  website          :string           default("")
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  canonical_id     :integer          indexed
#  event_series_id  :integer          not null, indexed
#
# Indexes
#
#  index_events_on_canonical_id                 (canonical_id)
#  index_events_on_country_code_and_state_code  (country_code,state_code)
#  index_events_on_event_series_id              (event_series_id)
#  index_events_on_kind                         (kind)
#  index_events_on_name                         (name)
#  index_events_on_slug                         (slug)
#
# Foreign Keys
#
#  canonical_id     (canonical_id => events.id)
#  event_series_id  (event_series_id => event_series.id)
#
class Event < ApplicationRecord
  include Geocodeable
  include Suggestable
  include Sluggable
  include Event::TypesenseSearchable

  geocodeable :location_and_country_code
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

  # Event involvement associations
  has_many :event_involvements, dependent: :destroy
  has_many :involved_users, -> { where(event_involvements: {involvementable_type: "User"}) },
    through: :event_involvements, source: :involvementable, source_type: "User"
  has_many :involved_event_series, -> { where(event_involvements: {involvementable_type: "EventSeries"}) },
    through: :event_involvements, source: :involvementable, source_type: "EventSeries"

  accepts_nested_attributes_for :event_involvements, allow_destroy: true, reject_if: :all_blank

  has_object :assets
  has_object :schedule
  has_object :static_metadata
  has_object :tickets
  has_object :sponsors_file
  has_object :cfp_file
  has_object :involvements_file
  has_object :transcripts_file
  has_object :venue
  has_object :videos_file

  # validations
  validates :name, presence: true
  validates :kind, presence: true
  validates :country_code, inclusion: {in: Country.valid_country_codes}, allow_nil: true
  validates :canonical, exclusion: {in: ->(event) { [event] }, message: "can't be itself"}
  validates :date_precision, presence: true
  validates :description, length: {maximum: 350}, allow_blank: true

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

  def upcoming?
    start_date.present? && start_date >= Date.today
  end

  def past?
    end_date.present? && end_date < Date.today
  end

  def self.find_by_name_or_alias(name)
    return nil if name.blank?

    event = find_by(name: name)
    return event if event

    alias_record = ::Alias.find_by(aliasable_type: "Event", name: name)
    alias_record&.aliasable
  end

  def self.find_by_slug_or_alias(slug)
    return nil if slug.blank?

    event = find_by(slug: slug)
    return event if event

    alias_record = ::Alias.find_by(aliasable_type: "Event", slug: slug)
    alias_record&.aliasable
  end

  def self.grouped_by_country
    all.group_by(&:country_code)
      .map { |code, evts| [Country.find_by(country_code: code), evts] }
      .reject { |country, _| country.nil? }
      .sort_by { |country, _| country.name }
  end

  def sync_aliases_from_list(alias_names)
    Array.wrap(alias_names).each do |alias_name|
      slug = alias_name.parameterize

      existing_own = slug_aliases.find_by(name: alias_name) || slug_aliases.find_by(slug: slug)

      if existing_own
        existing_own.update(name: alias_name) if existing_own.name != alias_name
        next
      end

      existing_global = ::Alias.find_by(aliasable_type: "Event", name: alias_name)
      existing_global ||= ::Alias.find_by(aliasable_type: "Event", slug: slug)

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

  def location_and_country_code
    default_country = series&.static_metadata&.default_country_code

    [location, default_country].compact.join(", ")
  end

  def location_and_country_code_previously_changed?
    location_previously_changed?
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

  def held_in_sentence
    country&.held_in_sentence || ""
  end

  def to_location
    @to_location ||= Location.from_record(self)
  end

  delegate :country, :state, :city_object, to: :to_location

  def description
    if super&.present?
      super
    else
      event_summary_description
    end
  end

  def event_summary_description
    event_name = series.organisation? ? name : series.name
    "#{event_name} is a #{static_metadata.frequency} #{kind}#{held_in_sentence}#{talks_text}#{keynote_speakers_text}."
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
      description: event_summary_description,
      og: {
        title: name,
        type: :website,
        image: {
          _: Router.image_path(card_image_path),
          alt: name
        },
        description: event_summary_description,
        site_name: "RubyEvents.org"
      },
      twitter: {
        card: "summary_large_image",
        site: "@rubyevents_org",
        title: name,
        description: event_summary_description,
        image: {
          src: Router.image_path(card_image_path)
        }
      }
    }
  end

  def sort_date
    start_date || end_date || Time.at(0)
  end

  def watchable_talks?
    talks.where.not(video_provider: ["scheduled", "not_published", "not_recorded"]).exists?
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
      description: description,
      location: location,
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
