# -*- SkipSchemaAnnotations

class Event::Assets < ActiveRecord::AssociatedObject
  IMAGES_BASE_PATH = Rails.root.join("app", "assets", "images")

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

  def image_path_for(filename)
    event_path = [base_path, filename].join("/")
    series_default_path = [default_series_path, filename].join("/")
    global_default_path = [default_path, filename].join("/")

    return event_path if (IMAGES_BASE_PATH / event_path).exist?
    return series_default_path if (IMAGES_BASE_PATH / series_default_path).exist?

    global_default_path
  end

  def image_path_if_exists(filename)
    event_path = [base_path, filename].join("/")

    (IMAGES_BASE_PATH / event_path).exist? ? event_path : nil
  end

  def banner_path
    image_path_for("banner.webp")
  end

  def card_path
    image_path_for("card.webp")
  end

  def avatar_path
    image_path_for("avatar.webp")
  end

  def featured_path
    image_path_for("featured.webp")
  end

  def poster_path
    image_path_for("poster.webp")
  end

  def stickers
    Sticker.for_event(event)
  end

  def sticker_paths
    stickers.map(&:file_path)
  end

  def sticker_path
    sticker_paths.first
  end

  def sticker?
    sticker_paths.any?
  end

  def stamp_paths
    Dir.glob(IMAGES_BASE_PATH.join(base_path, "stamp*.webp")).map { |path|
      Pathname.new(path).relative_path_from(IMAGES_BASE_PATH).to_s
    }.sort
  end

  def stamp_path
    stamp_paths.first
  end

  def stamp?
    stamp_paths.any?
  end
end
