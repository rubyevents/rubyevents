require "ferrum"
require "open-uri"

class Talk::ThumbnailGenerator
  BASE = {width: 640, height: 360}.freeze
  SCALE = 2

  WIDTH = BASE[:width] * SCALE
  HEIGHT = BASE[:height] * SCALE

  IMAGES_BASE_PATH = Rails.root.join("app", "assets", "images")
  LOGO_PATH = Rails.root.join("app", "assets", "images", "logo.png")
  DISK_BASE_PATH = Rails.root.join("tmp", "thumbnails", "generated")

  PARTIALS = {
    "classic" => "card",
    "spotlight" => "spotlight"
  }.freeze

  VARIANTS = PARTIALS.keys.freeze
  DEFAULT_VARIANT = "classic"

  attr_reader :talk, :variant

  def initialize(talk, variant: DEFAULT_VARIANT)
    @talk = talk
    @variant = VARIANTS.include?(variant.to_s) ? variant.to_s : DEFAULT_VARIANT
  end

  def generate
    html_content = render_html
    return nil unless html_content

    browser = Ferrum::Browser.new(**browser_options)

    begin
      data_uri = "data:text/html;base64,#{Base64.strict_encode64(html_content)}"
      browser.go_to(data_uri)
      sleep 1.5 # allow remote avatar images to load
      browser.screenshot(format: :png, full: true)
    ensure
      browser.quit
    end
  rescue => e
    Rails.logger.error("Talk::ThumbnailGenerator failed for talk #{talk.id}: #{e.message}")
    Rails.logger.error(e.backtrace.first(10).join("\n"))
    nil
  end

  def save_to_storage
    screenshot_data = generate
    return nil unless screenshot_data

    decoded_data = Base64.decode64(screenshot_data)

    talk.generated_thumbnail.attach(
      io: StringIO.new(decoded_data),
      filename: "thumbnail-#{talk.slug}#{variant_suffix}.png",
      content_type: "image/png"
    )

    talk.generated_thumbnail
  end

  def exists?
    talk.generated_thumbnail.attached?
  end

  def disk_path
    event_slug = talk.event&.slug.presence || "no-event"
    DISK_BASE_PATH.join(event_slug, "#{talk.slug}#{variant_suffix}.png")
  end

  def write_to_disk
    screenshot_data = generate
    return nil unless screenshot_data

    path = disk_path
    FileUtils.mkdir_p(path.dirname)
    File.binwrite(path, Base64.decode64(screenshot_data))

    path
  end

  private

  def render_html
    speakers = talk.speakers.to_a
    background = background_value

    locals = {
      talk: talk,
      event: talk.event,
      event_name: talk.event_name,
      location: talk.location.presence,
      formatted_date: talk.date ? I18n.l(talk.date, format: :long, default: talk.date.to_s) : nil,
      speakers: speakers.map { |speaker| {name: speaker.name, avatar_url: speaker.avatar_url(size: 480), github: speaker.github_handle.presence} },
      featured_background: background,
      bg_style: background_style(background),
      featured_color: featured_color,
      event_logo_uri: inline_local_image(talk.event&.avatar_image_path),
      app_logo_uri: inline_file(LOGO_PATH),
      width: WIDTH,
      height: HEIGHT
    }

    partial_html = ApplicationController.render(
      partial: "talks/thumbnail/#{PARTIALS[variant]}",
      locals: locals
    )

    wrap_in_html_document(partial_html)
  end

  def variant_suffix
    (variant == DEFAULT_VARIANT) ? "" : "-#{variant}"
  end

  def background_value
    bg = talk.event&.static_metadata&.featured_background.presence || "#081625"
    return {type: :image, value: bg} if bg.start_with?("data:")

    {type: :color, value: bg}
  end

  def featured_color
    talk.event&.static_metadata&.featured_color.presence || "#FFFFFF"
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

  def inline_file(path)
    return nil unless path && File.exist?(path)

    ext = File.extname(path).delete(".").downcase
    mime = (ext == "svg") ? "svg+xml" : ext
    "data:image/#{mime};base64,#{Base64.strict_encode64(File.binread(path))}"
  end

  def wrap_in_html_document(partial_html)
    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <style>
          * { margin: 0; padding: 0; box-sizing: border-box; }
          html, body {
            width: #{WIDTH}px;
            height: #{HEIGHT}px;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", sans-serif;
          }
          img { display: block; }
        </style>
      </head>
      <body>
        #{partial_html}
      </body>
      </html>
    HTML
  end

  def browser_options
    options = {
      headless: true,
      window_size: [WIDTH, HEIGHT],
      timeout: 30
    }

    if chrome_ws_url
      options[:url] = chrome_ws_url
    else
      options[:browser_options] = {
        "no-sandbox": true,
        "disable-gpu": true,
        "disable-dev-shm-usage": true
      }
    end

    options
  end

  def chrome_ws_url
    return ENV["CHROME_WS_URL"] if ENV["CHROME_WS_URL"].present?
    return nil if Rails.env.local?

    service_name = Rails.env.staging? ? "rubyvideo_staging" : "rubyvideo"
    "ws://#{service_name}-chrome:3000"
  end
end
