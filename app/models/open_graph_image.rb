require "ferrum"

class OpenGraphImage
  WIDTH = 1200
  HEIGHT = 630
  OUTPUT_PATH = Rails.root.join("app/assets/images/logo_og_image.png")
  SLOTS = [
    {cx: 78, cy: 84, size: 94, rotation: -9, opacity: 0.95},
    {cx: 252, cy: 58, size: 70, rotation: 6, opacity: 0.82},
    {cx: 420, cy: 86, size: 58, rotation: -6, opacity: 0.7},
    {cx: 600, cy: 66, size: 64, rotation: 8, opacity: 0.74},
    {cx: 782, cy: 88, size: 58, rotation: -5, opacity: 0.7},
    {cx: 952, cy: 58, size: 72, rotation: 7, opacity: 0.82},
    {cx: 1124, cy: 90, size: 92, rotation: -8, opacity: 0.95},
    {cx: 66, cy: 256, size: 80, rotation: 5, opacity: 0.88},
    {cx: 98, cy: 420, size: 74, rotation: -7, opacity: 0.85},
    {cx: 196, cy: 168, size: 54, rotation: 9, opacity: 0.66},
    {cx: 1134, cy: 256, size: 80, rotation: -5, opacity: 0.88},
    {cx: 1104, cy: 420, size: 74, rotation: 7, opacity: 0.85},
    {cx: 1012, cy: 168, size: 54, rotation: -9, opacity: 0.66},
    {cx: 88, cy: 546, size: 92, rotation: 8, opacity: 0.95},
    {cx: 268, cy: 574, size: 66, rotation: -6, opacity: 0.78},
    {cx: 452, cy: 556, size: 58, rotation: 7, opacity: 0.7},
    {cx: 622, cy: 576, size: 62, rotation: -5, opacity: 0.72},
    {cx: 800, cy: 558, size: 58, rotation: 6, opacity: 0.7},
    {cx: 980, cy: 574, size: 68, rotation: -7, opacity: 0.78},
    {cx: 1124, cy: 544, size: 90, rotation: 9, opacity: 0.95}
  ].freeze

  attr_reader :output_path

  def initialize(output_path: OUTPUT_PATH)
    @output_path = Pathname(output_path)
  end

  def generate!(browser: Ferrum::Browser.new(**browser_options))
    browser.go_to("data:text/html;base64,#{Base64.strict_encode64(render_html)}")
    sleep 1.5
    screenshot_data = browser.screenshot(format: :png, full: true)
    output_path.binwrite(Base64.decode64(screenshot_data))
    output_path
  ensure
    browser&.quit
  end

  private

  def render_html
    ApplicationController.render(
      template: "open_graph_images/home",
      layout: "open_graph_image",
      locals: {logos: slotted_logos}
    )
  end

  def slotted_logos
    logo_images(SLOTS.size).zip(SLOTS).map { |logo, slot| slot.merge(logo) }
  end

  def logo_images(limit)
    logo_candidates.lazy
      .filter { it.event_image_for("avatar.webp") }
      .first(limit)
      .map do |event|
        path = event.event_image_for("avatar.webp")
        file = Event::Assets::IMAGES_BASE_PATH.join(path)
        data = Base64.strict_encode64(file.binread)
        {src: "data:image/webp;base64,#{data}", alt: event.name}
      end
  end

  def logo_candidates
    Event.not_meetup
      .where.not(home_sort_date: nil)
      .order(
        Arel.sql("ABS(JULIANDAY(home_sort_date) - JULIANDAY(CURRENT_DATE))"),
        talks_count: :desc
      )
  end

  def browser_options
    {
      headless: true,
      window_size: [WIDTH, HEIGHT],
      timeout: 30,
      browser_options: {
        "no-sandbox": true,
        "disable-gpu": true,
        "disable-dev-shm-usage": true
      }
    }
  end
end
