class Sticker
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :code, :string
  attribute :name, :string
  attribute :file_path, :string
  attribute :event
  attribute :event_slug, :string

  def self.all
    @all_stickers ||= load_stickers_from_filesystem
  end

  def self.for_event(event)
    return [] unless event&.slug

    prefix = "#{event.event_image_path}/"

    all.select { |sticker|
      (sticker.event_slug.present? && sticker.event_slug == event.slug) ||
        sticker.file_path.start_with?(prefix)
    }
  end

  def asset_path
    ActionController::Base.helpers.asset_path(file_path)
  end

  def event
    return @event if defined?(@event)

    @event = Event.find_by(slug: event_slug) if event_slug.present?
  end

  def self.load_stickers_from_filesystem
    images_directory = Rails.root.join("app", "assets", "images")
    event_sticker_files = Dir.glob(images_directory.join("events", "**", "sticker*.webp"))

    event_sticker_files.map { |file| create_sticker_from_event_file(file, images_directory) }
      .compact
      .uniq { |sticker| sticker.code }
      .sort_by(&:name)
  end

  def self.create_sticker_from_event_file(file, images_directory)
    relative_path = Pathname.new(file).relative_path_from(images_directory)
    path_parts = relative_path.each_filename.to_a
    event_slug = path_parts[-2]
    basename = Pathname.new(file).basename(".webp").to_s

    return nil unless event_slug.present? && basename.present?

    event = Event.find_by(slug: event_slug)

    variant_suffix = basename.sub(/^sticker[_-]?/i, "")
    code_parts = [event&.slug || event_slug, basename].compact
    code = code_parts.join("-").upcase

    display_name = event&.name || event_slug.titleize
    variant_label = variant_suffix.present? ? "Sticker #{variant_suffix.titleize}" : "Sticker"
    name = "#{display_name} (#{variant_label})"

    new(
      code: code,
      name: name,
      file_path: relative_path.to_s,
      event: event,
      event_slug: event_slug
    )
  end
end
