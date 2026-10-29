class Event::StaticMetadata < ActiveRecord::AssociatedObject
  extension do
    def featured_metadata? = static_metadata.featured_background?
  end

  delegate :published_date, :home_sort_date, :time_zone, to: :static_repository, allow_nil: true

  def bsky = social(:bsky)
  def facebook = social(:facebook)
  def github = social(:github)
  def instagram = social(:instagram)
  def linkedin = social(:linkedin)
  def luma = social(:luma)
  def mastodon = social(:mastodon)
  def meetup = social(:meetup)
  def twitter = social(:twitter)

  def kind
    return static_repository.kind if static_repository&.kind
    return "conference" if event.series&.conference?
    return "meetup" if event.series&.meetup?

    "event"
  end

  def conference?
    kind == "conference"
  end

  def meetup?
    kind == "meetup"
  end

  def retreat?
    kind == "retreat"
  end

  def hackathon?
    kind == "hackathon"
  end

  def start_date
    @start_date ||= static_repository.start_date.present? ? static_repository.start_date : event.talks.minimum(:date)
  rescue => _e
    event.talks.minimum(:date)
  end

  def end_date
    @end_date ||= static_repository.end_date.present? ? static_repository.end_date : event.talks.map(&:date).max
  rescue => _e
    event.talks.map(&:date).max
  end

  def date_precision
    static_repository.date_precision || "day"
  end

  def year
    static_repository.year.present? ? static_repository.year : event.talks.first.try(:date).try(:year)
  rescue => _e
    event.talks.first.try(:date).try(:year)
  end

  def featured_background?
    return false unless static_repository
    return false unless event.assets.has_custom_asset?("featured.webp")

    static_repository.featured_background.present? || static_repository.featured_color.present?
  end

  def featured_background
    return "black" unless event.assets.has_custom_asset?("featured.webp")

    static_repository&.featured_background.presence || "black"
  end

  def featured_color
    return "white" unless event.assets.has_custom_asset?("featured.webp")

    static_repository&.featured_color.presence || "white"
  end

  def banner_background
    return "#081625" unless event.assets.has_custom_asset?("banner.webp")

    static_repository&.banner_background.presence || "#081625"
  end

  def location
    static_repository&.location&.presence || "Earth"
  end

  def coordinates
    static_repository&.coordinates
  end

  def country
    return nil if location.blank?

    Country.find(location.to_s.split(",").last&.strip)
  end

  def last_edition?
    static_repository&.last_edition || false
  end

  def hybrid?
    !!static_repository.try(:hybrid) || false
  end

  def description
    static_repository.try(:[], "description")
  end

  def start_time
    static_repository.try(:[], "start_time")
  end

  def end_time
    static_repository.try(:[], "end_time")
  end

  def own_links
    [*MeetupLinks::FIELDS, "tickets_url"].index_with { |field| static_repository.try(:[], field) }.compact_blank
  end

  def cancelled?
    static_repository&.status == "cancelled"
  end

  def playlist
    static_repository&.playlist
  end

  def data_folder
    Pathname.new(File.dirname(static_repository.file_path)) if static_repository&.file_path
  end

  private

  def social(field)
    static_repository.try(field).presence || event.series&.static_metadata&.try(field)
  end

  def static_repository
    @static_repository ||= Static::Event.find_by_slug(event.slug)
  end
end
