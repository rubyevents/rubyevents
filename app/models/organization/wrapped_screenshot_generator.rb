require "ferrum"

class Organization::WrappedScreenshotGenerator
  YEAR = 2025
  SCALE = 2

  DIMENSIONS = {
    horizontal: {width: 800 * SCALE, height: 420 * SCALE}
  }.freeze

  attr_reader :organization

  def initialize(organization)
    @organization = organization
  end

  def save_to_storage(locals)
    png_data = generate_horizontal_card(locals)
    return false unless png_data

    organization.wrapped_card_horizontal.attach(
      io: StringIO.new(png_data),
      filename: "#{organization.slug}-#{YEAR}-wrapped.png",
      content_type: "image/png"
    )

    true
  rescue => e
    Rails.logger.error("Organization::WrappedScreenshotGenerator#save_to_storage failed: #{e.message}")
    false
  end

  def generate_horizontal_card(locals)
    html_content = render_card_html(locals)
    return nil unless html_content

    dimensions = DIMENSIONS[:horizontal]
    browser = Ferrum::Browser.new(**browser_options(dimensions))

    begin
      # Use data URI to inject HTML directly (works with remote Chrome)
      data_uri = "data:text/html;base64,#{Base64.strict_encode64(html_content)}"
      browser.go_to(data_uri)
      sleep 1
      screenshot_data = browser.screenshot(format: :png, full: true)
      Base64.decode64(screenshot_data)
    ensure
      browser.quit
    end
  rescue => e
    Rails.logger.error("Organization::WrappedScreenshotGenerator failed: #{e.message}")
    Rails.logger.error(e.backtrace.first(10).join("\n"))
    nil
  end

  private

  def browser_options(dimensions)
    options = {
      headless: true,
      window_size: [dimensions[:width], dimensions[:height]],
      timeout: 30
    }

    if chrome_ws_url
      # Connect to remote browserless Chrome service
      options[:url] = chrome_ws_url
    else
      # Local Chrome with sandbox options
      options[:browser_options] = {
        "no-sandbox": true,
        "disable-gpu": true,
        "disable-dev-shm-usage": true
      }
    end

    options
  end

  def chrome_ws_url
    # In production, connect to the chrome accessory via Kamal's Docker network
    # In development, use local Chrome (return nil)
    return nil unless Rails.env.production?

    "ws://rubyvideo-chrome:3000"
  end

  def render_card_html(locals)
    partial_html = ApplicationController.render(
      partial: "organizations/wrapped/pages/summary_card_horizontal",
      locals: locals
    )

    wrap_in_html_document(partial_html, locals)
  end

  def wrap_in_html_document(partial_html, locals)
    if organization.logo_url.present?
      partial_html = partial_html.gsub(
        /src="#{Regexp.escape(organization.logo_url)}"/,
        "src=\"#{organization.logo_url}\""
      )
    end

    logo_path = Rails.root.join("app/assets/images/logo.png")
    logo_data_uri = if File.exist?(logo_path)
      "data:image/png;base64,#{Base64.strict_encode64(File.binread(logo_path))}"
    else
      ""
    end
    partial_html = partial_html.gsub(/src="[^"]*logo[^"]*\.png"/, "src=\"#{logo_data_uri}\"")

    dimensions = DIMENSIONS[:horizontal]
    s = SCALE

    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <style>
          * { margin: 0; padding: 0; box-sizing: border-box; }

          html, body {
            width: #{dimensions[:width]}px;
            height: #{dimensions[:height]}px;
            max-height: #{dimensions[:height]}px;
          }

          body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            background: linear-gradient(135deg, #991b1b 0%, #450a0a 50%, #081625 100%);
            color: white;
            display: flex;
            flex-direction: column;
            overflow: hidden;
          }

          .flex { display: flex; }
          .flex-col { flex-direction: column; }
          .flex-1 { flex: 1; min-height: 0; }
          .items-center { align-items: center; }
          .justify-center { justify-content: center; }
          .text-center { text-align: center; }

          .gap-3 { gap: #{0.75 * s}rem; }
          .gap-4 { gap: #{1 * s}rem; }
          .gap-6 { gap: #{1.5 * s}rem; }
          .gap-12 { gap: #{3 * s}rem; }
          .mb-6 { margin-bottom: #{1.5 * s}rem; }
          .mt-1 { margin-top: #{0.25 * s}rem; }
          .mt-2 { margin-top: #{0.5 * s}rem; }
          .mt-4 { margin-top: #{1 * s}rem; }
          .mt-auto { margin-top: auto; }
          .p-3 { padding: #{0.75 * s}rem; }
          .p-8 { padding: #{2 * s}rem; }
          .py-3 { padding-top: #{0.75 * s}rem; padding-bottom: #{0.75 * s}rem; }
          .py-4 { padding-top: #{1 * s}rem; padding-bottom: #{1 * s}rem; }
          .px-6 { padding-left: #{1.5 * s}rem; padding-right: #{1.5 * s}rem; }
          .px-8 { padding-left: #{2 * s}rem; padding-right: #{2 * s}rem; }
          .px-12 { padding-left: #{3 * s}rem; padding-right: #{3 * s}rem; }
          .pt-8 { padding-top: #{2 * s}rem; }
          .pb-4 { padding-bottom: #{1 * s}rem; }

          .w-6 { width: #{1.5 * s}rem; }
          .h-6 { height: #{1.5 * s}rem; }
          .w-8 { width: #{2 * s}rem; }
          .h-8 { height: #{2 * s}rem; }
          .w-32 { width: #{8 * s}rem; }
          .h-32 { height: #{8 * s}rem; }
          .w-full { width: 100%; }
          .h-full { height: 100%; }

          .rounded-2xl { border-radius: #{1 * s}rem; }
          .rounded-full { border-radius: 9999px; }
          .overflow-hidden { overflow: hidden; }
          .object-contain { object-fit: contain; }
          .object-cover { object-fit: cover; }

          .border-4 { border-width: #{4 * s}px; border-style: solid; }
          .border-white { border-color: white; }

          .bg-white { background: white; }
          .bg-white\\/5 { background: rgba(255,255,255,0.05); }
          .bg-white\\/10 { background: rgba(255,255,255,0.1); }
          .bg-white\\/20 { background: rgba(255,255,255,0.2); }
          .backdrop-blur { backdrop-filter: blur(10px); }

          .grid { display: grid; }
          .grid-cols-2 { grid-template-columns: repeat(2, minmax(0, 1fr)); }

          .text-6xl { font-size: #{3.75 * s}rem; line-height: 1; }
          .text-5xl { font-size: #{3 * s}rem; line-height: 1; }
          .text-3xl { font-size: #{1.875 * s}rem; }
          .text-lg { font-size: #{1.125 * s}rem; }
          .text-sm { font-size: #{0.875 * s}rem; }
          .font-black { font-weight: 900; }
          .font-bold { font-weight: 700; }
          .text-white { color: white; }
          .text-red-200 { color: #FECACA; }
          .text-red-300 { color: #FCA5A5; }
          .text-red-300\\/60 { color: rgba(252,165,165,0.6); }
          .text-red-300\\/80 { color: rgba(252,165,165,0.8); }

          img { max-width: 100%; height: auto; }
        </style>
      </head>
      <body>
        #{partial_html}
      </body>
      </html>
    HTML
  end
end
