require "ferrum"
require "tempfile"

class User::WrappedImageGenerator
  YEAR = 2025
  WIDTH = 1200
  HEIGHT = 630

  attr_reader :user

  def initialize(user)
    @user = user
  end

  def generate
    html_content = render_html
    return nil unless html_content

    html_file = Tempfile.new(["wrapped-og", ".html"])
    html_file.write(html_content)
    html_file.close

    browser = Ferrum::Browser.new(
      headless: true,
      window_size: [WIDTH, HEIGHT],
      timeout: 30,
      browser_options: {
        "no-sandbox": true,
        "disable-gpu": true,
        "disable-dev-shm-usage": true
      }
    )

    begin
      browser.go_to("file://#{html_file.path}")
      sleep 1
      screenshot_data = browser.screenshot(format: :png, full: true)
      screenshot_data
    ensure
      browser.quit
      html_file.unlink
    end
  rescue => e
    Rails.logger.error("WrappedImageGenerator failed: #{e.message}")
    Rails.logger.error(e.backtrace.first(10).join("\n"))
    nil
  end

  def save_to_storage
    screenshot_data = generate
    return nil unless screenshot_data

    decoded_data = Base64.decode64(screenshot_data)
    filename = "wrapped-og-#{YEAR}-#{user.slug}.png"

    user.wrapped_og_image.attach(
      io: StringIO.new(decoded_data),
      filename: filename,
      content_type: "image/png"
    )

    user.wrapped_og_image
  end

  def exists?
    user.wrapped_og_image.attached?
  end

  private

  def render_html
    partial_html = ApplicationController.render(
      partial: "profiles/wrapped/pages/og_image",
      assigns: {user: user, year: YEAR}
    )

    wrap_in_html_document(partial_html)
  end

  def wrap_in_html_document(partial_html)
    logo_path = Rails.root.join("app/assets/images/logo.png")
    logo_data_uri = if File.exist?(logo_path)
      "data:image/png;base64,#{Base64.strict_encode64(File.binread(logo_path))}"
    else
      ""
    end

    partial_html = partial_html.gsub(/src="[^"]*logo[^"]*\.png"/, "src=\"#{logo_data_uri}\"")

    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <style>
          * { margin: 0; padding: 0; box-sizing: border-box; }

          body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            width: #{WIDTH}px;
            height: #{HEIGHT}px;
            background: linear-gradient(135deg, #DC2626 0%, #991B1B 100%);
            color: white;
            display: flex;
            flex-direction: column;
            padding: 2.5rem;
          }

          .flex-1 { flex: 1; }
          .flex { display: flex; }
          .flex-col { flex-direction: column; }
          .items-center { align-items: center; }
          .justify-center { justify-content: center; }

          .gap-3 { gap: 0.75rem; }

          .w-full { width: 100%; }
          .w-28 { width: 7rem; }
          .w-8 { width: 2rem; }
          .h-28 { height: 7rem; }
          .h-8 { height: 2rem; }

          .mt-auto { margin-top: auto; }
          .mb-1 { margin-bottom: 0.25rem; }
          .mb-3 { margin-bottom: 0.75rem; }
          .mb-4 { margin-bottom: 1rem; }
          .mb-6 { margin-bottom: 1.5rem; }
          .mb-8 { margin-bottom: 2rem; }

          .rounded-full { border-radius: 9999px; }
          .overflow-hidden { overflow: hidden; }

          .border-4 { border-width: 4px; border-style: solid; }
          .border-white { border-color: white; }

          .bg-white\\/20 { background: rgba(255,255,255,0.2); }

          .text-7xl { font-size: 4.5rem; line-height: 1; }
          .text-4xl { font-size: 2.25rem; }
          .text-3xl { font-size: 1.875rem; }
          .text-2xl { font-size: 1.5rem; }
          .text-xl { font-size: 1.25rem; }
          .text-lg { font-size: 1.125rem; }
          .font-black { font-weight: 900; }
          .font-bold { font-weight: 700; }
          .text-red-200 { color: #FECACA; }
          .text-white { color: white; }

          .object-cover { object-fit: cover; }

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
