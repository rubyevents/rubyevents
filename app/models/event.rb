# rubocop:disable Layout/LineLength
# == Schema Information
#
# Table name: events
#
#  id              :integer          not null, primary key
#  cfp_close_date  :date
#  cfp_link        :string
#  cfp_open_date   :date
#  city            :string
#  country_code    :string
#  date            :date
#  date_precision  :string           default("day"), not null
#  end_date        :date
#  kind            :string           default("event"), not null, indexed
#  name            :string           default(""), not null, indexed
#  slug            :string           default(""), not null, indexed
#  start_date      :date
#  talks_count     :integer          default(0), not null
#  website         :string           default("")
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  canonical_id    :integer          indexed
#  organisation_id :integer          not null, indexed
#
# Indexes
#
#  index_events_on_canonical_id     (canonical_id)
#  index_events_on_kind             (kind)
#  index_events_on_name             (name)
#  index_events_on_organisation_id  (organisation_id)
#  index_events_on_slug             (slug)
#
# Foreign Keys
#
#  canonical_id     (canonical_id => events.id)
#  organisation_id  (organisation_id => organisations.id)
#
# rubocop:enable Layout/LineLength
class Event < ApplicationRecord
  include Suggestable
  include Sluggable
  slug_from :name

  # associations
  belongs_to :organisation, strict_loading: false
  has_many :talks, dependent: :destroy, inverse_of: :event, foreign_key: :event_id
  has_many :watchable_talks, -> { watchable }, class_name: "Talk"
  has_many :speakers, -> { distinct }, through: :talks
  has_many :keynote_speakers, -> { joins(:talks).where(talks: {kind: "keynote"}).distinct },
    through: :talks, source: :speakers
  has_many :topics, -> { distinct }, through: :talks
  has_many :event_sponsors, dependent: :destroy
  has_many :sponsors, through: :event_sponsors
  belongs_to :canonical, class_name: "Event", optional: true
  has_many :aliases, class_name: "Event", foreign_key: "canonical_id"

  has_object :schedule
  has_object :static_metadata
  has_object :sponsors_file
  has_object :cfp

  def talks_in_running_order(child_talks: true)
    talks.in_order_of(:video_id, video_ids_in_running_order(child_talks: child_talks))
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
  scope :ft_search, ->(query) { where("lower(events.name) LIKE ?", "%#{query.downcase}%") }
  scope :past, -> { where(end_date: ..Date.today).order(end_date: :desc) }
  scope :upcoming, -> { where(start_date: Date.today..).order(start_date: :asc) }

  # enums
  enum :kind, ["event", "conference", "meetup"].index_by(&:itself), default: "event"
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
    Rails.root.join("data", organisation.slug, slug)
  end

  def videos_file?
    videos_file_path.exist?
  end

  def videos_file_path
    data_folder.join("videos.yml")
  end

  def videos_file
    YAML.load_file(videos_file_path)
  end

  def video_ids_in_running_order(child_talks: true)
    if child_talks
      videos_file.flat_map { |talk|
        [talk.dig("video_id"), *talk["talks"]&.map { |child_talk|
          child_talk.dig("video_id")
        }]
      }
    else
      videos_file.map { |talk| talk.dig("video_id") }
    end
  end

  def suggestion_summary
    <<~HEREDOC
      Event: #{name}
      #{description}
      #{city}
      #{country_code}
      #{organisation.name}
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

    event_name = organisation.organisation? ? name : organisation.name

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
    ["events", organisation.slug, slug].join("/")
  end

  def default_event_image_path
    ["events", "default"].join("/")
  end

  def default_organisation_image_path
    ["events", organisation.slug, "default"].join("/")
  end

  def event_image_or_default_for(filename)
    event_path = [event_image_path, filename].join("/")
    default_organisation_path = [default_organisation_image_path, filename].join("/")
    default_path = [default_event_image_path, filename].join("/")

    base = Rails.root.join("app", "assets", "images")

    return event_path if (base / event_path).exist?
    return default_organisation_path if (base / default_organisation_path).exist?

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

  # sticker - 350x350
  def sticker_image_path
    event_image_for("sticker.webp")
  end

  def sticker?
    sticker_image_path.present?
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
    self[:website].presence || organisation.website
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
