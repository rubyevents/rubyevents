require "ferrum"

class User::WrappedScreenshotGenerator
  YEAR = 2025
  SCALE = 2

  DIMENSIONS = {
    vertical: {width: 400 * SCALE, height: 700 * SCALE},
    horizontal: {width: 800 * SCALE, height: 420 * SCALE}
  }.freeze

  attr_reader :user, :orientation

  def initialize(user, orientation: :vertical)
    @user = user
    @orientation = orientation.to_sym
  end

  def generate
    html_content = render_card_html
    return nil unless html_content

    dimensions = DIMENSIONS[orientation]
    browser = Ferrum::Browser.new(**browser_options(dimensions))

    begin
      # Use data URI to inject HTML directly (works with remote Chrome)
      data_uri = "data:text/html;base64,#{Base64.strict_encode64(html_content)}"
      browser.go_to(data_uri)
      sleep 1
      screenshot_data = browser.screenshot(format: :png, full: true)
      screenshot_data
    ensure
      browser.quit
    end
  rescue => e
    Rails.logger.error("WrappedScreenshotGenerator failed: #{e.message}")
    Rails.logger.error(e.backtrace.first(10).join("\n"))
    nil
  end

  def save_to_storage
    screenshot_data = generate
    return nil unless screenshot_data

    decoded_data = Base64.decode64(screenshot_data)
    filename = "wrapped-#{orientation}-#{YEAR}-#{user.slug}.png"

    attachment = (orientation == :horizontal) ? user.wrapped_card_horizontal : user.wrapped_card

    attachment.attach(
      io: StringIO.new(decoded_data),
      filename: filename,
      content_type: "image/png"
    )

    attachment
  end

  def exists?
    if orientation == :horizontal
      user.wrapped_card_horizontal.attached?
    else
      user.wrapped_card.attached?
    end
  end

  def self.generate_all(user)
    vertical = new(user, orientation: :vertical)
    horizontal = new(user, orientation: :horizontal)

    vertical.save_to_storage
    horizontal.save_to_storage
  end

  private

  def render_card_html
    assigns = build_assigns
    partial_name = (orientation == :horizontal) ? "summary_card_horizontal" : "summary_card"
    partial_html = render_partial(partial_name, assigns)

    wrap_in_html_document(partial_html)
  end

  def build_assigns
    year_range = Date.new(YEAR, 1, 1)..Date.new(YEAR, 12, 31)

    watched_talks_in_year = user.watched_talks
      .includes(talk: [:event, :speakers, :approved_topics])
      .where(created_at: year_range)

    total_talks_watched = watched_talks_in_year.count
    total_watch_time_seconds = watched_talks_in_year.sum(&:progress_seconds)
    total_watch_time_hours = (total_watch_time_seconds / 3600.0).round(1)

    events_attended_in_year = user.participated_events.where(start_date: year_range)
    talks_given_in_year = user.kept_talks.where(date: year_range)
    countries_visited = events_attended_in_year.map(&:country).compact.uniq

    top_topics = watched_talks_in_year
      .flat_map { |wt| wt.talk.approved_topics }
      .compact
      .reject { |topic| topic.name.downcase.in?(["ruby", "ruby on rails"]) }
      .tally
      .sort_by { |_, count| -count }
      .first(5)

    top_speakers = watched_talks_in_year
      .flat_map { |wt| wt.talk.speakers }
      .compact
      .reject { |speaker| speaker.id == user.id }
      .tally
      .sort_by { |_, count| -count }
      .first(5)

    favorite_speaker = top_speakers.first&.first

    total_views_on_talks = talks_given_in_year.sum(:view_count)

    involvements_in_year = user.event_involvements
      .joins(:event)
      .where(events: {start_date: year_range})

    personality = determine_personality(top_topics)

    {
      user: user,
      year: YEAR,
      total_talks_watched: total_talks_watched,
      total_watch_time_hours: total_watch_time_hours,
      events_attended_in_year: events_attended_in_year,
      talks_given_in_year: talks_given_in_year,
      countries_visited: countries_visited,
      top_topics: top_topics,
      top_speakers: top_speakers,
      favorite_speaker: favorite_speaker,
      total_views_on_talks: total_views_on_talks,
      involvements_in_year: involvements_in_year,
      personality: personality
    }
  end

  def render_partial(partial_name, locals)
    ApplicationController.render(
      partial: "profiles/wrapped/pages/#{partial_name}",
      locals: locals
    )
  end

  def wrap_in_html_document(partial_html)
    logo_path = Rails.root.join("app/assets/images/logo.png")
    logo_data_uri = if File.exist?(logo_path)
      "data:image/png;base64,#{Base64.strict_encode64(File.binread(logo_path))}"
    else
      ""
    end

    partial_html = partial_html.gsub(/src="[^"]*logo[^"]*\.png"/, "src=\"#{logo_data_uri}\"")

    if orientation == :horizontal
      wrap_horizontal_html_document(partial_html)
    else
      wrap_vertical_html_document(partial_html)
    end
  end

  def wrap_horizontal_html_document(partial_html)
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
          .p-12 { padding: #{3 * s}rem; }
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

          .rounded-full { border-radius: 9999px; }
          .rounded-2xl { border-radius: #{1 * s}rem; }
          .rounded-3xl { border-radius: #{1.5 * s}rem; }
          .overflow-hidden { overflow: hidden; }
          .object-cover { object-fit: cover; }
          .object-contain { object-fit: contain; }

          .border-4 { border-width: #{4 * s}px; border-style: solid; }
          .border-white { border-color: white; }
          .border-white\\/20 { border-color: rgba(255,255,255,0.2); }

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

  def wrap_vertical_html_document(partial_html)
    dimensions = DIMENSIONS[:vertical]
    s = SCALE

    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <style>
          * { margin: 0; padding: 0; box-sizing: border-box; }

          body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            width: #{dimensions[:width]}px;
            height: #{dimensions[:height]}px;
            background: linear-gradient(135deg, #991b1b 0%, #450a0a 50%, #081625 100%);
            color: white;
            display: flex;
            flex-direction: column;
            padding: #{2 * s}rem;
          }

          .flex-1 { flex: 1; }
          .flex { display: flex; }
          .flex-col { flex-direction: column; }
          .flex-wrap { flex-wrap: wrap; }
          .items-center { align-items: center; }
          .items-end { align-items: flex-end; }
          .justify-center { justify-content: center; }
          .text-center { text-align: center; }

          .w-full { width: 100%; }
          .w-24 { width: #{6 * s}rem; }
          .w-20 { width: #{5 * s}rem; }
          .w-8 { width: #{2 * s}rem; }
          .w-6 { width: #{1.5 * s}rem; }
          .h-24 { height: #{6 * s}rem; }
          .h-20 { height: #{5 * s}rem; }
          .h-8 { height: #{2 * s}rem; }
          .h-6 { height: #{1.5 * s}rem; }
          .max-w-xs { max-width: #{20 * s}rem; }

          .mx-auto { margin-left: auto; margin-right: auto; }
          .mt-auto { margin-top: auto; }
          .mt-3 { margin-top: #{0.75 * s}rem; }
          .mb-0 { margin-bottom: 0; }
          .mb-1 { margin-bottom: #{0.25 * s}rem; }
          .mb-2 { margin-bottom: #{0.5 * s}rem; }
          .mb-3 { margin-bottom: #{0.75 * s}rem; }
          .mb-4 { margin-bottom: #{1 * s}rem; }
          .mb-6 { margin-bottom: #{1.5 * s}rem; }
          .pt-2 { padding-top: #{0.5 * s}rem; }
          .pt-4 { padding-top: #{1 * s}rem; }
          .pb-1 { padding-bottom: #{0.25 * s}rem; }
          .p-2 { padding: #{0.5 * s}rem; }
          .px-2 { padding-left: #{0.5 * s}rem; padding-right: #{0.5 * s}rem; }
          .px-3 { padding-left: #{0.75 * s}rem; padding-right: #{0.75 * s}rem; }
          .px-4 { padding-left: #{1 * s}rem; padding-right: #{1 * s}rem; }
          .py-1 { padding-top: #{0.25 * s}rem; padding-bottom: #{0.25 * s}rem; }
          .py-2 { padding-top: #{0.5 * s}rem; padding-bottom: #{0.5 * s}rem; }
          .gap-1 { gap: #{0.25 * s}rem; }
          .gap-2 { gap: #{0.5 * s}rem; }
          .gap-3 { gap: #{0.75 * s}rem; }
          .gap-12 { gap: #{3 * s}rem; }
          .-space-x-2 > * + * { margin-left: #{-0.5 * s}rem; }

          .rounded-full { border-radius: 9999px; }
          .rounded-lg { border-radius: #{0.5 * s}rem; }
          .rounded { border-radius: #{0.25 * s}rem; }
          .overflow-hidden { overflow: hidden; }

          .border-2 { border-width: #{2 * s}px; border-style: solid; }
          .border-3 { border-width: #{3 * s}px; border-style: solid; }
          .border-4 { border-width: #{4 * s}px; border-style: solid; }
          .border-white { border-color: white; }
          .border-red-600 { border-color: #DC2626; }

          .bg-white\\/10 { background: rgba(255,255,255,0.1); }
          .bg-white\\/20 { background: rgba(255,255,255,0.2); }
          .bg-purple-500\\/30 { background: rgba(168,85,247,0.3); }

          .text-3xl { font-size: #{1.875 * s}rem; }
          .text-2xl { font-size: #{1.5 * s}rem; }
          .text-xl { font-size: #{1.25 * s}rem; }
          .text-lg { font-size: #{1.125 * s}rem; }
          .text-sm { font-size: #{0.875 * s}rem; }
          .text-xs { font-size: #{0.75 * s}rem; }
          .text-\\[10px\\] { font-size: #{10 * s}px; }
          .font-bold { font-weight: 700; }
          .text-red-200 { color: #FECACA; }
          .text-white { color: white; }

          .grid { display: grid; }
          .grid-cols-1 { grid-template-columns: repeat(1, minmax(0, 1fr)); }
          .grid-cols-2 { grid-template-columns: repeat(2, minmax(0, 1fr)); }
          .grid-cols-3 { grid-template-columns: repeat(3, minmax(0, 1fr)); }

          .object-cover { object-fit: cover; }
          .flex-shrink-0 { flex-shrink: 0; }
          .text-left { text-align: left; }
          .truncate { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
          .w-10 { width: #{2.5 * s}rem; }
          .h-10 { height: #{2.5 * s}rem; }

          .personality-badge {
            background: linear-gradient(135deg, #DC2626 0%, #B91C1C 100%);
            color: white;
            padding: #{0.5 * s}rem #{1 * s}rem;
            border-radius: 9999px;
            font-weight: 700;
            font-size: #{0.875 * s}rem;
            display: inline-block;
            box-shadow: 0 #{4 * s}px #{14 * s}px rgba(220, 38, 38, 0.4);
          }

          img { max-width: 100%; height: auto; }
        </style>
      </head>
      <body>
        #{partial_html}
      </body>
      </html>
    HTML
  end

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
    # Use CHROME_WS_URL env var if set, otherwise derive from environment
    # In development/test, use local Chrome (return nil)
    return ENV["CHROME_WS_URL"] if ENV["CHROME_WS_URL"].present?
    return nil if Rails.env.local?

    # Kamal names accessories as <service>-<accessory>
    # Production: rubyevents-chrome, Staging: rubyevents_staging-chrome
    service_name = Rails.env.staging? ? "rubyevents_staging" : "rubyevents"
    "ws://#{service_name}-chrome:3000"
  end

  def determine_personality(top_topics)
    return "Ruby Explorer" if top_topics.empty?

    all_topic_names = top_topics.map { |topic, _| topic.name.downcase }

    personality_matches = {
      "Hotwire Hero" => %w[hotwire turbo stimulus turbo-native],
      "Frontend Artisan" => %w[javascript css frontend ui vue react angular viewcomponent],
      "Testing Guru" => %w[testing test-driven rspec minitest capybara vcr],
      "Performance Optimizer" => %w[performance optimization caching benchmarking memory profiling],
      "Security Champion" => %w[security authentication authorization encryption vulnerability],
      "Data Architect" => %w[postgresql database sql activerecord mysql sqlite redis elasticsearch],
      "API Artisan" => %w[api graphql rest grpc json],
      "DevOps Pioneer" => %w[devops deployment docker kubernetes aws heroku kamal ci/cd],
      "Architecture Astronaut" => %w[architecture microservices monolith modular design-patterns solid],
      "Ruby Internist" => %w[ruby-vm ruby-internals yjit garbage-collection jruby truffleruby mruby parser ast],
      "Concurrency Connoisseur" => %w[concurrency async threading ractor fiber sidekiq background],
      "AI Adventurer" => %w[machine-learning artificial-intelligence ai llm openai langchain],
      "Community Champion" => %w[open-source community mentorship diversity inclusion],
      "Growth Mindset" => %w[career-development personal-development leadership team-building mentorship],
      "Code Craftsperson" => %w[refactoring code-quality clean-code debugging error-handling]
    }

    personality_matches.each do |personality, keywords|
      if all_topic_names.any? { |topic| keywords.any? { |keyword| topic.include?(keyword) } }
        return personality
      end
    end

    top_topic = top_topics.first&.first&.name&.downcase

    case top_topic
    when /rails/
      "Rails Enthusiast"
    when /developer.?experience|dx/
      "DX Advocate"
    when /web/
      "Web Developer"
    when /software/
      "Software Craftsperson"
    when /gem/
      "Gem Hunter"
    when /debug/
      "Bug Squasher"
    when /learn|education|teach/
      "Eternal Learner"
    when /startup|entrepreneur|business/
      "Ruby Entrepreneur"
    when /legacy|maintain/
      "Legacy Whisperer"
    when /mobile|ios|android/
      "Mobile Maverick"
    when /real.?time|websocket|action.?cable/
      "Real-Time Ranger"
    when /background|job|queue|sidekiq/
      "Background Boss"
    when /monolith|majestic/
      "Monolith Master"
    else
      "Rubyist"
    end
  end
end
