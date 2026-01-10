class Event::StaticMetadata < ActiveRecord::AssociatedObject
  extension do
    def featured_metadata? = static_metadata.featured_background?
  end

  delegate :published_date, :home_sort_date, to: :static_repository, allow_nil: true

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

  def frequency
    static_repository&.frequency || event.series.frequency
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

    static_repository.featured_background.present? || static_repository.featured_color.present?
  end

  def featured_background
    return static_repository.featured_background if static_repository.featured_background.present?

    "black"
  rescue => e
    raise "No featured background found for #{event.name} :  #{e.message}. You might have to restart your Rails server." if Rails.env.local?
    "black"
  end

  def featured_color
    static_repository.featured_color.present? ? static_repository.featured_color : "white"
  rescue => e
    raise "No featured color found for #{event.name} :  #{e.message}. You might have to restart your Rails server." if Rails.env.local?
    "white"
  end

  def banner_background
    static_repository.banner_background.present? ? static_repository.banner_background : "#081625"
  rescue => e
    raise "No featured background found for #{event.name} :  #{e.message}. You might have to restart your Rails server." if Rails.env.local?
    "#081625"
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

  private

  def static_repository
    @static_repository ||= Static::Event.find_by_slug(event.slug)
  end
end
