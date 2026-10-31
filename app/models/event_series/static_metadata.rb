class EventSeries::StaticMetadata < ActiveRecord::AssociatedObject
  delegate :bsky, :facebook, :github, :guild, :luma, :linkedin, :mastodon,
    :meetup, :twitter, :vimeo, :website, to: :static_repository, allow_nil: true

  def instagram
    static_repository.try(:instagram)
  end

  def ended?
    static_repository.try(:ended) || false
  end

  def default_country_code
    static_repository.try(:default_country_code) || nil
  end

  def all_youtube_channels
    static_repository&.all_youtube_channels || []
  end

  def all_youtube_channel_ids
    static_repository&.all_youtube_channel_ids || []
  end

  def default_image(filename)
    static_repository&.default_image(filename)
  end

  def description
    static_repository.try(:description)
  end

  def aliases
    Array(static_repository.try(:[], "aliases"))
  end

  def time_zone
    name = static_repository.try(:[], "timezone")

    ActiveSupport::TimeZone[name] if name.present?
  end

  def featured_color
    static_repository.try(:featured_color).presence
  end

  def accent_color
    [featured_color, static_repository.try(:featured_background)].find { |color| accent_color?(color) }
  end

  def banner_background
    return "#081625" unless default_image("banner.webp")

    static_repository.try(:banner_background).presence || "#081625"
  end

  def own_links
    MeetupLinks::FIELDS.index_with { |field| static_repository.try(:[], field) }.compact_blank
  end

  def data_folder
    Pathname.new(File.dirname(static_repository.file_path)) if static_repository&.file_path
  end

  private

  def accent_color?(color)
    return false unless color.to_s.match?(/\A#\h{6}\z/)

    red, green, blue = color.delete("#").scan(/../).map { |channel| channel.hex / 255.0 }
    lightness = ([red, green, blue].max + [red, green, blue].min) / 2

    ([red, green, blue].max - [red, green, blue].min) > 0.25 && lightness.between?(0.2, 0.75)
  end

  def static_repository
    @static_repository ||= Static::EventSeries.find_by_slug(event_series.slug)
  end
end
