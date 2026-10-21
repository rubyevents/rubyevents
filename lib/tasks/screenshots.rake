# frozen_string_literal: true

require "fileutils"
require "gum"
require "net/http"
require "open3"

namespace :screenshots do
  desc "Capture screenshots of pages affected by data/ changes since the git baseline (set SKIP_SEED=1 to skip seeding)"
  task changed: :environment do
    Screenshots::Capture.new.run
  end
end

module Screenshots
  # One page to screenshot, plus everything needed to name the file and
  # describe it in the pull request body.
  Target = Struct.new(:series, :event, :path, :slug, :alt, keyword_init: true) do
    def file_name
      "#{slug}.png"
    end
  end

  # Maps a changed data file to the page it renders on. Slugs are the folder
  # names, which Static::Validators::IdMatchesFolder keeps in sync with the `id`
  # in event.yml and series.yml, so no record lookup is needed.
  #
  # schedule.yml is the only file with more than one page: every day has its own
  # view, and Events::SchedulesController#show matches params[:date] against the
  # YAML value verbatim (a mismatch raises), so the dates are used as-is.
  EVENT_ROUTES = {
    "cfp.yml" => ["/events/%{event}/cfp", "CFP"],
    "event.yml" => ["/events/%{event}", "event page"],
    "involvements.yml" => ["/events/%{event}/involvements", "involvements"],
    "sponsors.yml" => ["/events/%{event}/sponsors", "sponsors"],
    "venue.yml" => ["/events/%{event}/venue", "venue"],
    "videos.yml" => ["/events/%{event}/talks", "talks"]
  }.freeze

  VIEWPORT_SIZE = "1440,900"

  class Capture
    DEFAULT_BASE_URL = "http://localhost:#{ENV.fetch("PORT", 3000)}"

    attr_reader :base_url, :output_dir

    def initialize(base_url: ENV.fetch("BASE_URL", DEFAULT_BASE_URL), output_dir: Rails.root.join("tmp"), seed: ENV["SKIP_SEED"].blank?)
      @base_url = base_url.to_s.chomp("/")
      @output_dir = Pathname(output_dir)
      @seed = seed

      # GitBaseline keeps changed_paths and baseline_ref in the ClassMethods
      # module ActiveSupport::Concern builds, which only lands on classes that
      # include the concern. Rake files are loaded before the app autoloader is
      # set up, so the mixin has to wait until run time.
      singleton_class.include GitBaseline::ClassMethods
    end

    def run
      targets = targets_for_changed_files

      if targets.empty?
        puts Gum.style("No data files changed that map to a screenshot.", foreground: "8")
        return
      end

      print_plan(targets)
      seed_series(targets)
      ensure_dev_server!

      FileUtils.mkdir_p(output_dir)
      targets.each { |target| capture(target) }
      print_markdown(targets)
    end

    private

    attr_reader :seed

    # --- Mapping ------------------------------------------------------------

    def targets_for_changed_files
      targets = Array(changed_paths).flat_map { |path| targets_for_path(path) }
      targets.uniq(&:path).sort_by { |target| [target.series, target.event.to_s, target.path] }
    end

    def targets_for_path(relative_path)
      series, event, file = split_data_path(relative_path)
      return [] if series.nil?

      event ? targets_for_event(series, event, file) : targets_for_series(series, file)
    end

    # data/{series}/series.yml, or data/{series}/{event}/{file}.yml
    def split_data_path(relative_path)
      parts = relative_path.to_s.split("/")
      return [] unless parts.first == "data"

      case parts.size
      when 3 then [parts[1], nil, parts[2]]
      when 4 then [parts[1], parts[2], parts[3]]
      else []
      end
    end

    def targets_for_series(series, file)
      return [] unless file == "series.yml"
      return [] unless data_file_exists?(series, nil, file)

      [build_target(series: series, path: "/events/series/#{series}", alt: "#{series} series page")]
    end

    def targets_for_event(series, event, file)
      if (route = EVENT_ROUTES[file])
        return [] unless data_file_exists?(series, event, file)

        return [build_target(series: series, event: event, path: format(route.first, event: event), alt: "#{event} #{route.last}")]
      end

      return [] unless file == "schedule.yml"

      schedule_targets(series, event)
    end

    def schedule_targets(series, event)
      return [] unless data_file_exists?(series, event, "schedule.yml")

      schedule_dates(series, event).map do |date|
        build_target(
          series: series,
          event: event,
          path: "/events/#{event}/schedule/day/#{date}",
          alt: "#{event} schedule for #{date}"
        )
      end
    end

    def schedule_dates(series, event)
      document = Yerba.parse_file(data_path(series, event, "schedule.yml").to_s)
      Array(document.value_at("days")).filter_map { |day| day["date"].presence }
    rescue => e
      puts Gum.style("Could not read schedule days for #{event}: #{e.message}", foreground: "1")
      []
    end

    # A file that was deleted (or never existed) has no page worth capturing.
    def data_file_exists?(series, event, file)
      data_path(series, event, file).exist?
    end

    def data_path(series, event, file)
      data_dir.join(series, *[event].compact, file)
    end

    def data_dir
      @data_dir ||= Rails.root.join("data")
    end

    def build_target(series:, path:, alt:, event: nil)
      Target.new(series: series, event: event, path: path, slug: slug_for(path), alt: alt)
    end

    # events/balkanruby-2025/sponsors => balkanruby-2025-sponsors
    def slug_for(path)
      path.to_s.split("/").reject { |part| part.empty? || part == "events" }.join("-").parameterize
    end

    # --- Seeding ------------------------------------------------------------

    def seed_series(targets)
      series_slugs = targets.map(&:series).uniq
      return if series_slugs.empty? || !seed

      puts Gum.style("Seeding #{series_slugs.join(", ")}", foreground: "6")

      series_slugs.each do |series|
        record = Static::EventSeries.find_by_slug(series)

        if record
          record.import!
        else
          puts Gum.style("Event series '#{series}' not found, skipping seed.", foreground: "1")
        end
      end
    end

    # --- Dev server ---------------------------------------------------------

    def ensure_dev_server!
      response = Net::HTTP.get_response(URI.join("#{base_url}/up"))
      return if response.is_a?(Net::HTTPSuccess)

      raise "Dev server at #{base_url} responded #{response.code}."
    rescue SystemCallError, SocketError, Net::OpenTimeout, Net::ReadTimeout => e
      raise "Could not reach the dev server at #{base_url} (#{e.message}). Start it with `bin/dev`, or set BASE_URL."
    end

    # --- Capture ------------------------------------------------------------

    def capture(target)
      url = "#{base_url}#{target.path}"
      destination = output_dir.join(target.file_name)

      print "  #{target.path} ... "

      output, success = run_playwright(url, destination)

      if success
        puts Gum.style("ok", foreground: "2")
      else
        puts Gum.style("failed", foreground: "1")
        puts output.lines.map { |line| "    #{line}" }.join
        failures << target
      end
    rescue => e
      puts Gum.style("failed", foreground: "1")
      puts "    #{e.message}"
      failures << target
    end

    def run_playwright(url, destination)
      output, _stderr, status = Open3.capture3(
        "npx", "--no-install", "playwright", "screenshot",
        "--full-page",
        "--viewport-size", VIEWPORT_SIZE,
        url,
        destination.to_s
      )

      [output, status.success?]
    rescue Errno::ENOENT
      ["npx was not found on PATH.", false]
    end

    def failures
      @failures ||= []
    end

    # --- Reporting ----------------------------------------------------------

    def print_plan(targets)
      puts
      puts Gum.style("Baseline: #{baseline_ref.presence || "(none found)"}", foreground: "8")
      puts Gum.style("Seeding: #{seed ? "yes" : "skipped (SKIP_SEED)"}", foreground: "8")
      puts Gum.style("#{targets.size} page(s) to capture:", foreground: "4")
      targets.each { |target| puts "  #{target.path}" }
      puts
    end

    def print_markdown(targets)
      captured = targets - failures

      puts
      puts "## Screenshots"
      puts
      captured.each { |target| puts "![#{target.alt}](./tmp/#{target.file_name})" }

      return if failures.empty?

      puts
      puts Gum.style("#{failures.size} page(s) were not captured:", foreground: "1")
      failures.each { |target| puts "  #{target.path}" }
    end
  end
end
