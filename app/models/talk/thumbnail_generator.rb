require "open-uri"
require "open3"

class Talk::ThumbnailGenerator
  BASE = {width: 640, height: 360}.freeze
  SCALE = 2

  WIDTH = BASE[:width] * SCALE
  HEIGHT = BASE[:height] * SCALE

  IMAGES_BASE_PATH = Rails.root.join("app", "assets", "images")
  LOGO_PATH = Rails.root.join("app", "assets", "images", "logo.png")
  DISK_BASE_PATH = Rails.root.join("tmp", "thumbnails", "generated")

  AVATAR_FETCH_TIMEOUT = 5
  CARD_AVATAR_SIZE = 160
  SPOTLIGHT_AVATAR_SIZE = 440
  IMAGE_CACHE_TTL = 1.week

  SATORI_IMAGE_MIMES = %w[image/png image/jpeg image/gif image/svg+xml].freeze
  MIME_BY_EXT = {"jpg" => "image/jpeg", "jpeg" => "image/jpeg", "svg" => "image/svg+xml"}.freeze
  MAGICK_BIN = (system("command -v magick > /dev/null 2>&1") ? "magick" : "convert").freeze

  PARTIALS = {
    "classic" => "card",
    "spotlight" => "spotlight"
  }.freeze

  VARIANTS = PARTIALS.keys.freeze
  DEFAULT_VARIANT = "classic"

  def self.vips_available?
    return @vips_available unless @vips_available.nil?

    @vips_available = begin
      require "vips"
      true
    rescue LoadError
      false
    end
  end

  attr_reader :talk, :variant

  def initialize(talk, variant: DEFAULT_VARIANT)
    @talk = talk
    @variant = VARIANTS.include?(variant.to_s) ? variant.to_s : DEFAULT_VARIANT
  end

  def generate
    partial_html = render_partial_html
    return nil unless partial_html

    base64 = Renderer.render_png_base64(partial_html, WIDTH, HEIGHT)
    return nil if base64.blank?

    Base64.decode64(base64)
  rescue => e
    Rails.logger.error("Talk::ThumbnailGenerator failed for talk #{talk.id}: #{e.message}")
    Rails.logger.error(e.backtrace.first(10).join("\n"))
    nil
  end

  def storage_filename
    "thumbnail-#{talk.slug}-#{variant}-#{talk.thumbnail_cache_version}.png"
  end

  def stored_blob
    blob = talk.generated_thumbnail

    blob if blob.attached? && blob.filename.to_s == storage_filename
  end

  def cached_png
    stored_blob&.download
  end

  def save_to_storage
    png = generate
    return nil unless png

    store(png)
  end

  def generate_and_store
    png = generate
    return nil unless png

    store(png)

    png
  end

  def exists?
    stored_blob.present?
  end

  def disk_path
    event_slug = talk.event&.slug.presence || "no-event"
    DISK_BASE_PATH.join(event_slug, "#{talk.slug}#{variant_suffix}.png")
  end

  def write_to_disk
    png = generate
    return nil unless png

    path = disk_path
    FileUtils.mkdir_p(path.dirname)
    File.binwrite(path, png)

    path
  end

  private

  def store(png)
    talk.generated_thumbnail.attach(
      io: StringIO.new(png),
      filename: storage_filename,
      content_type: "image/png"
    )
  end

  def render_partial_html
    speakers = talk.speakers.to_a.reject { |speaker| speaker.name.to_s.strip.casecmp?("TODO") }
    background = background_value
    avatar_size = avatar_fetch_size(speakers.size)

    locals = {
      talk: talk,
      event: talk.event,
      event_name: talk.event_name,
      location: talk.location.presence,
      formatted_date: talk.date ? I18n.l(talk.date, format: :long, default: talk.date.to_s) : nil,
      speakers: speakers.map { |speaker| {name: speaker.name, avatar_url: inline_remote_image(speaker.avatar_url(size: avatar_size)), github: speaker.github_handle.presence} },
      featured_background: background,
      bg_style: background_style(background),
      featured_color: featured_color,
      event_logo_uri: inline_local_image(talk.event&.avatar_image_path),
      app_logo_uri: inline_file(LOGO_PATH),
      width: WIDTH,
      height: HEIGHT
    }

    ApplicationController.render(
      partial: "talks/thumbnail/#{PARTIALS[variant]}",
      locals: locals
    )
  end

  def avatar_fetch_size(speaker_count)
    (variant == "spotlight" && speaker_count == 1) ? SPOTLIGHT_AVATAR_SIZE : CARD_AVATAR_SIZE
  end

  def variant_suffix
    (variant == DEFAULT_VARIANT) ? "" : "-#{variant}"
  end

  def background_value
    background = talk.thumbnail_background
    return {type: :image, value: background} if background.start_with?("data:")

    {type: :color, value: background}
  end

  def featured_color
    talk.thumbnail_text_color
  end

  def background_style(background)
    if background[:type] == :image
      "background-image: url('#{background[:value]}'); background-size: cover; background-position: center;"
    else
      "background-color: #{background[:value]};"
    end
  end

  def inline_local_image(relative_path)
    return nil if relative_path.blank?

    inline_file(IMAGES_BASE_PATH.join(relative_path))
  end

  def inline_remote_image(url)
    return nil if url.blank?
    return url if url.start_with?("data:")

    Rails.cache.fetch(["thumbnail-generator", "remote-image", url], expires_in: IMAGE_CACHE_TTL) do
      io = URI.parse(url).open(open_timeout: AVATAR_FETCH_TIMEOUT, read_timeout: AVATAR_FETCH_TIMEOUT)
      image_data_uri(io.read, io.content_type.presence || "image/jpeg")
    end
  rescue => e
    Rails.logger.warn("Talk::ThumbnailGenerator could not inline avatar #{url}: #{e.message}")
    url
  end

  def inline_file(path)
    return nil unless path && File.exist?(path)

    Rails.cache.fetch(["thumbnail-generator", "file-image", path.to_s, File.mtime(path).to_i], expires_in: IMAGE_CACHE_TTL) do
      inline_file_uncached(path)
    end
  end

  def inline_file_uncached(path)
    ext = File.extname(path).delete(".").downcase
    mime = MIME_BY_EXT.fetch(ext, "image/#{ext}")
    image_data_uri(File.binread(path), mime)
  end

  def image_data_uri(bytes, mime)
    unless SATORI_IMAGE_MIMES.include?(mime)
      bytes = convert_to_png(bytes)
      return nil unless bytes
      mime = "image/png"
    end

    "data:#{mime};base64,#{Base64.strict_encode64(bytes)}"
  end

  def convert_to_png(bytes)
    convert_to_png_with_vips(bytes) || convert_to_png_with_magick(bytes)
  end

  def convert_to_png_with_vips(bytes)
    return nil unless self.class.vips_available?

    Vips::Image.new_from_buffer(bytes, "").pngsave_buffer
  rescue => e
    Rails.logger.warn("Talk::ThumbnailGenerator vips conversion failed: #{e.message}")
    nil
  end

  def convert_to_png_with_magick(bytes)
    out, status = Open3.capture2(MAGICK_BIN, "-", "png:-", stdin_data: bytes, binmode: true)
    return out if status.success?

    Rails.logger.warn("Talk::ThumbnailGenerator #{MAGICK_BIN} exited #{status.exitstatus} converting image to PNG")
    nil
  rescue => e
    Rails.logger.warn("Talk::ThumbnailGenerator image conversion failed: #{e.message}")
    nil
  end
end
