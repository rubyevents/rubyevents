# -*- SkipSchemaAnnotations

class Event::Assets < ActiveRecord::AssociatedObject
  IMAGES_BASE_PATH = Rails.root.join("app", "assets", "images")

  DIMENSIONS = {
    "avatar" => {width: 256, height: 256},
    "banner" => {width: 1300, height: 350},
    "card" => {width: 600, height: 350},
    "featured" => {width: 615, height: 350},
    "poster" => {width: 600, height: 350},
    "sticker" => {width: 350, height: 350},
    "stamp" => {width: 512, height: 512}
  }.freeze

  extension do
    delegate :stickers, :sticker?, :stamp?, to: :assets

    def event_image_path = assets.base_path
    def event_image_for(filename) = assets.image_path_if_exists(filename)
    def banner_image_path = assets.banner_path
    def card_image_path = assets.card_path
    def avatar_image_path = assets.avatar_path
    def featured_image_path = assets.featured_path
    def poster_image_path = assets.poster_path
    def sticker_image_paths = assets.sticker_paths
    def sticker_image_path = assets.sticker_path
    def stamp_image_paths = assets.stamp_paths
    def stamp_image_path = assets.stamp_path

    def avatar_url
      return nil unless avatar_image_path

      Router.image_url(avatar_image_path)
    end

    def banner_url
      return nil unless banner_image_path

      Router.image_url(banner_image_path)
    end
  end

  def base_path
    ["events", event.series.slug, event.slug].join("/")
  end

  def default_path
    ["events", "default"].join("/")
  end

  def default_series_path
    ["events", event.series.slug, "default"].join("/")
  end

  def image_path_for(filename, event_file = event_file(filename))
    image_path(event_file) || image_path(series_default_file(filename)) || [default_path, filename].join("/")
  end

  def image_path_if_exists(filename)
    image_path(event_file(filename))
  end

  def has_custom_asset?(filename)
    (event_file(filename) || series_default_file(filename)).present?
  end

  def banner_path
    image_path_for("banner.webp", static_event&.banner)
  end

  def card_path
    image_path_for("card.webp", static_event&.card)
  end

  def avatar_path
    image_path_for("avatar.webp", static_event&.avatar)
  end

  def featured_path
    image_path_for("featured.webp", static_event&.featured)
  end

  def poster_path
    image_path_for("poster.webp", static_event&.poster)
  end

  def stickers
    static_event&.stickers.to_a.sort_by(&:name)
  end

  def sticker_paths
    stickers.map(&:image_path)
  end

  def sticker_path
    sticker_paths.first
  end

  def sticker?
    sticker_paths.any?
  end

  def stamp_paths
    static_event&.stamps.to_a.map(&:image_path)
  end

  def stamp_path
    stamp_paths.first
  end

  def stamp?
    stamp_paths.any?
  end

  private

  def static_event
    return @static_event if defined?(@static_event)

    @static_event = Static::Event.find_by_slug(event.slug)
  end

  def event_file(filename)
    static_event&.images&.[](filename)
  end

  def series_default_file(filename)
    static_event&.series&.default_images&.[](filename)
  end

  def image_path(file)
    file.relative_path_from(IMAGES_BASE_PATH).to_s if file&.exist?
  end
end
