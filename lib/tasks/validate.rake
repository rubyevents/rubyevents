# frozen_string_literal: true

namespace :validate do
  require "gum"
  require "json_schemer"
  require "yaml"

  def validate_files(glob_pattern, schema_class, file_type, &custom_validation)
    schema = JSON.parse(schema_class.new.to_json_schema[:schema].to_json)
    schemer = JSONSchemer.schema(schema)

    files = Dir.glob(Rails.root.join(glob_pattern))
    valid_count = 0
    invalid_files = []

    files.each do |file|
      data = YAML.load_file(file)
      errors = schemer.validate(data).to_a

      custom_validation&.call(data, errors)

      if errors.empty?
        valid_count += 1
      else
        relative_path = file.sub("#{Rails.root}/data/", "")
        invalid_files << {path: relative_path, errors: errors}
      end
    end

    if invalid_files.any?
      puts Gum.style("Invalid #{file_type} files (#{invalid_files.count}):", foreground: "1")
      puts
      invalid_files.each do |file|
        puts Gum.style("❌ #{file[:path]}", foreground: "1")
        gh_action_anotation = (ENV["GITHUB_ACTIONS"] == "true") ? "::error file=data/#{file[:path]},line=1::" : "::error::"
        file[:errors].each { |e| puts "#{gh_action_anotation} #{e["error"]} at #{e["data_pointer"]}" }
        puts
      end
    end

    if invalid_files.any?
      puts Gum.style("#{file_type}: #{valid_count} valid, #{invalid_files.count} invalid out of #{files.count} files", foreground: "1")
    else
      puts Gum.style("#{file_type}: #{valid_count} valid out of #{files.count} files", foreground: "2")
    end

    invalid_files.empty?
  end

  def validate_array_files(glob_pattern, schema_class, file_type)
    schema = JSON.parse(schema_class.new.to_json_schema[:schema].to_json)
    schemer = JSONSchemer.schema(schema)

    files = Dir.glob(Rails.root.join(glob_pattern))
    valid_count = 0
    invalid_files = []

    files.each do |file|
      data = YAML.load_file(file)
      file_errors = []

      Array(data).each_with_index do |item, index|
        errors = schemer.validate(item).to_a

        errors.each do |error|
          error["data_pointer"] = "/#{index}#{error["data_pointer"]}"
          error["item_label"] = item["name"] || item["title"] || item["id"] || "index #{index}"
          file_errors << error
        end
      end

      if file_errors.empty?
        valid_count += 1
      else
        relative_path = file.sub("#{Rails.root}/data/", "")
        invalid_files << {path: relative_path, errors: file_errors}
      end
    end

    if invalid_files.any?
      puts Gum.style("Invalid #{file_type} files (#{invalid_files.count}):", foreground: "1")
      puts
      invalid_files.each do |file|
        puts Gum.style("❌ #{file[:path]}", foreground: "1")
        file[:errors].first(10).each do |e|
          gh_action_annotation = (ENV["GITHUB_ACTIONS"] == "true") ? "::error file=data/#{file[:path]},line=1::" : "::error::"
          puts " #{gh_action_annotation} #{e["error"]} at #{e["data_pointer"]} (#{e["item_label"]})"
        end
        puts "   ... and #{file[:errors].count - 10} more errors" if file[:errors].count > 10
        puts
      end
    end

    if invalid_files.any?
      puts Gum.style("#{file_type}: #{valid_count} valid, #{invalid_files.count} invalid out of #{files.count} files", foreground: "1")
    else
      puts Gum.style("#{file_type}: #{valid_count} valid out of #{files.count} files", foreground: "2")
    end

    invalid_files.empty?
  end

  desc "Validate all cfp.yml files against CFPSchema"
  task cfps: :environment do
    success = validate_array_files("data/**/cfp.yml", CFPSchema, "cfp.yml")
    exit 1 unless success
  end

  desc "Validate all event.yml files against EventSchema"
  task events: :environment do
    success = validate_files("data/**/event.yml", EventSchema, "event.yml") do |data, errors|
      is_meetup = data["kind"] == "meetup"

      unless is_meetup
        if data["start_date"].nil? || data["start_date"].to_s.strip.empty?
          errors << {"error" => "start_date is required for non-meetup events", "data_pointer" => "/start_date"}
        end

        if data["end_date"].nil? || data["end_date"].to_s.strip.empty?
          errors << {"error" => "end_date is required for non-meetup events", "data_pointer" => "/end_date"}
        end
      end
    end

    exit 1 unless success
  end

  desc "Validate all series.yml files against SeriesSchema"
  task series: :environment do
    success = validate_files("data/*/series.yml", SeriesSchema, "series.yml")
    exit 1 unless success
  end

  desc "Validate all sponsors.yml files against SeriesSchema"
  task sponsors: :environment do
    success = validate_array_files("data/**/sponsors.yml", SponsorsSchema, "sponsors.yml")
    exit 1 unless success
  end

  desc "Validate all venue.yml files against VenueSchema"
  task venues: :environment do
    success = validate_files("data/**/venue.yml", VenueSchema, "venue.yml")
    exit 1 unless success
  end

  desc "Validate speakers.yml against SpeakerSchema"
  task speakers: :environment do
    success = validate_array_files("data/speakers.yml", SpeakerSchema, "speakers.yml")
    exit 1 unless success
  end

  desc "Validate all videos.yml files against VideoSchema"
  task videos: :environment do
    success = validate_array_files("data/**/videos.yml", VideoSchema, "videos.yml")
    exit 1 unless success
  end

  desc "Validate all schedule.yml files against ScheduleSchema"
  task schedules: :environment do
    success = validate_files("data/**/schedule.yml", ScheduleSchema, "schedule.yml")
    exit 1 unless success
  end

  desc "Validate featured_cities.yml against FeaturedCitySchema"
  task featured_cities: :environment do
    success = validate_array_files("data/featured_cities.yml", FeaturedCitySchema, "featured_cities.yml")
    exit 1 unless success
  end

  desc "Validate all involvements.yml files against InvolvementSchema"
  task involvements: :environment do
    success = validate_array_files("data/**/involvements.yml", InvolvementSchema, "involvements.yml")
    exit 1 unless success
  end

  desc "Validate all transcripts.yml files against TranscriptSchema"
  task transcripts: :environment do
    success = validate_array_files("data/**/transcripts.yml", TranscriptSchema, "transcripts.yml")
    exit 1 unless success
  end

  def validate_unique_speaker_fields
    speakers = YAML.load_file(Rails.root.join("data/speakers.yml"))
    success = true

    slug_duplicates = speakers.map { |s| s["slug"] }.compact.tally.select { |_, count| count > 1 }
    github_duplicates = speakers.map { |s| s["github"] }.select(&:present?).tally.select { |_, count| count > 1 }

    if slug_duplicates.any?
      puts Gum.style("Duplicate speaker slugs found (#{slug_duplicates.count}):", foreground: "1")
      puts
      slug_duplicates.each do |slug, count|
        puts Gum.style("❌ #{slug} (#{count} occurrences)", foreground: "1")
      end
      puts
      success = false
    else
      puts Gum.style("✓ All speaker slugs are unique", foreground: "2")
    end

    if github_duplicates.any?
      puts Gum.style("Duplicate speaker GitHub handles found (#{github_duplicates.count}):", foreground: "1")
      puts
      github_duplicates.each do |github, count|
        puts Gum.style("❌ #{github} (#{count} occurrences)", foreground: "1")
      end
      puts
      success = false
    else
      puts Gum.style("✓ All speaker GitHub handles are unique", foreground: "2")
    end

    success
  end

  desc "Validate that speaker slugs and GitHub handles are unique"
  task unique_speakers: :environment do
    exit 1 unless validate_unique_speaker_fields
  end

  def validate_speakers_in_videos
    speakers_data = YAML.load_file(Rails.root.join("data/speakers.yml"))
    known_names = Set.new

    speakers_data.each do |speaker|
      known_names << speaker["name"]
      Array(speaker["aliases"]).each { |a| known_names << a["name"] }
    end

    files = Dir.glob(Rails.root.join("data/**/videos.yml"))
    missing = []

    files.each do |file|
      data = YAML.load_file(file)
      relative_path = file.sub("#{Rails.root}/data/", "")

      Array(data).each do |video|
        Array(video["speakers"]).each do |name|
          unless known_names.include?(name)
            missing << {path: relative_path, speaker: name}
          end
        end

        Array(video["talks"]).each do |talk|
          Array(talk["speakers"]).each do |name|
            unless known_names.include?(name)
              missing << {path: relative_path, speaker: name}
            end
          end
        end
      end
    end

    if missing.any?
      unique_speakers = missing.map { |m| m[:speaker] }.uniq.sort

      puts Gum.style("Speakers referenced in videos.yml but missing from speakers.yml (#{unique_speakers.count}):", foreground: "1")
      puts

      missing.group_by { |m| m[:speaker] }.sort_by { |name, _| name }.each do |name, occurrences|
        puts Gum.style("❌ #{name}", foreground: "1")
        occurrences.each { |o| puts "   #{o[:path]}" }
      end

      puts
      false
    else
      puts Gum.style("✓ All speakers in videos.yml exist in speakers.yml", foreground: "2")
      true
    end
  end

  desc "Validate that all speakers in videos.yml exist in speakers.yml"
  task speakers_in_videos: :environment do
    exit 1 unless validate_speakers_in_videos
  end

  desc "Validate that all Static::Video records have unique ids"
  task unique_video_ids: :environment do
    all_ids = []

    Static::Video.all.each do |video|
      all_ids << video.id
      video.talks.each { |talk| all_ids << talk.id }
    end

    duplicates = all_ids.tally.select { |_id, count| count > 1 }

    if duplicates.any?
      puts Gum.style("Duplicate video ids found (#{duplicates.count}):", foreground: "1")
      puts

      duplicates.each do |id, count|
        puts Gum.style("❌ #{id} (#{count} occurrences)", foreground: "1")
      end

      puts

      exit 1
    else
      puts Gum.style("✓ All video ids are unique", foreground: "2")
    end
  end

  desc "Validate that all YouTube videos have a published_at date"
  task youtube_published_at: :environment do
    missing_published_at = []

    Static::Video.all.each do |video|
      if video.video_provider == "youtube" && (video.published_at.blank? || video.published_at == "TODO")
        missing_published_at << video
      end

      video.talks.each do |talk|
        if talk.video_provider == "youtube" && (talk.published_at.blank? || talk.published_at == "TODO")
          missing_published_at << talk
        end
      end
    end

    if missing_published_at.any?
      puts Gum.style("YouTube videos missing published_at date (#{missing_published_at.count}):", foreground: "1")
      puts

      missing_published_at.each do |video|
        puts Gum.style("❌ #{video.id} (#{video.title})", foreground: "1")
      end

      puts

      exit 1
    else
      puts Gum.style("✓ All YouTube videos have a published_at date", foreground: "2")
    end
  end

  def validate_speaker_duplicates
    report = Gum.spin("Checking for speaker duplicates...", spinner: "dot") do
      User::DuplicateDetector.report
    end

    has_duplicates = report != "No duplicates found."

    if has_duplicates
      puts Gum.style(report, foreground: "1")
      puts
      puts Gum.style("To fix: Make sure the name in speakers.yml matches the reference in the videos.yml files.", foreground: "3")
      puts
    else
      puts Gum.style("✓ No unresolved speaker duplicates found", foreground: "2")
    end

    !has_duplicates
  end

  desc "Validate that there are no unresolved speaker duplicates"
  task speaker_duplicates: :environment do
    exit 1 unless validate_speaker_duplicates
  end

  def build_city_alias_lookup
    alias_to_canonical = {}

    Static::City.all.each do |city|
      Array(city.aliases).each do |alias_name|
        alias_to_canonical[alias_name.downcase] = city.name
      end
    end

    alias_to_canonical
  end

  def validate_event_city_names
    alias_to_canonical = build_city_alias_lookup
    files = Dir.glob(Rails.root.join("data/**/event.yml"))
    issues = []

    files.each do |file|
      data = YAML.load_file(file)
      location = data["location"]

      next if location.blank?

      city_part = location.split(",").first&.strip

      next if city_part.blank?

      canonical = alias_to_canonical[city_part.downcase]

      if canonical && canonical.downcase != city_part.downcase
        relative_path = file.sub("#{Rails.root}/data/", "")

        issues << {
          path: relative_path,
          field: "location",
          current: city_part,
          canonical: canonical,
          value: location
        }
      end
    end

    if issues.any?
      puts Gum.style("Events using city aliases instead of canonical names (#{issues.count}):", foreground: "1")
      puts

      issues.each do |issue|
        puts Gum.style("❌ #{issue[:path]}", foreground: "1")
        puts "   #{issue[:field]}: \"#{issue[:value]}\""
        puts "   Should use \"#{issue[:canonical]}\" instead of \"#{issue[:current]}\""
        puts
      end

      false
    else
      puts Gum.style("✓ All events use canonical city names", foreground: "2")

      true
    end
  end

  def check_city_alias(city_name, field, path, alias_to_canonical, issues)
    return if city_name.blank?

    canonical = alias_to_canonical[city_name.downcase]

    if canonical && canonical.downcase != city_name.downcase
      issues << {
        path: path,
        field: field,
        current: city_name,
        canonical: canonical,
        value: city_name
      }
    end
  end

  desc "Validate that event locations use canonical city names (not aliases)"
  task event_city_names: :environment do
    exit 1 unless validate_event_city_names
  end

  def validate_video_city_names
    alias_to_canonical = build_city_alias_lookup
    files = Dir.glob(Rails.root.join("data/**/videos.yml"))
    issues = []

    files.each do |file|
      data = YAML.load_file(file)
      relative_path = file.sub("#{Rails.root}/data/", "")

      Array(data).each_with_index do |video, index|
        location = video["location"]

        next if location.blank?

        city_part = location.split(",").first&.strip

        next if city_part.blank?
        next if city_part.downcase == "online" || city_part.downcase == "remote"

        canonical = alias_to_canonical[city_part.downcase]

        if canonical && canonical.downcase != city_part.downcase
          video_id = video["video_id"] || video["id"] || "index #{index}"

          issues << {
            path: relative_path,
            field: "videos[#{video_id}].location",
            current: city_part,
            canonical: canonical,
            value: location
          }
        end
      end
    end

    if issues.any?
      puts Gum.style("Videos using city aliases instead of canonical names (#{issues.count}):", foreground: "1")
      puts
      issues.each do |issue|
        puts Gum.style("❌ #{issue[:path]}", foreground: "1")
        puts "   #{issue[:field]}: \"#{issue[:value]}\""
        puts "   Should use \"#{issue[:canonical]}\" instead of \"#{issue[:current]}\""
        puts
      end
      false
    else
      puts Gum.style("✓ All videos use canonical city names", foreground: "2")
      true
    end
  end

  desc "Validate that video locations use canonical city names (not aliases)"
  task video_city_names: :environment do
    exit 1 unless validate_video_city_names
  end

  desc "Validate all city-related data"
  task cities: [:event_city_names, :video_city_names]

  CSS_NAMED_COLORS = Set.new(%w[
    aliceblue antiquewhite aqua aquamarine azure beige bisque black blanchedalmond
    blue blueviolet brown burlywood cadetblue chartreuse chocolate coral
    cornflowerblue cornsilk crimson cyan darkblue darkcyan darkgoldenrod darkgray
    darkgreen darkgrey darkkhaki darkmagenta darkolivegreen darkorange darkorchid
    darkred darksalmon darkseagreen darkslateblue darkslategray darkslategrey
    darkturquoise darkviolet deeppink deepskyblue dimgray dimgrey dodgerblue
    firebrick floralwhite forestgreen fuchsia gainsboro ghostwhite gold goldenrod
    gray green greenyellow grey honeydew hotpink indianred indigo ivory khaki
    lavender lavenderblush lawngreen lemonchiffon lightblue lightcoral lightcyan
    lightgoldenrodyellow lightgray lightgreen lightgrey lightpink lightsalmon
    lightseagreen lightskyblue lightslategray lightslategrey lightsteelblue
    lightyellow lime limegreen linen magenta maroon mediumaquamarine mediumblue
    mediumorchid mediumpurple mediumseagreen mediumslateblue mediumspringgreen
    mediumturquoise mediumvioletred midnightblue mintcream mistyrose moccasin
    navajowhite navy oldlace olive olivedrab orange orangered orchid palegoldenrod
    palegreen paleturquoise palevioletred papayawhip peachpuff peru pink plum
    powderblue purple rebeccapurple red rosybrown royalblue saddlebrown salmon
    sandybrown seagreen seashell sienna silver skyblue slateblue slategray
    slategrey snow springgreen steelblue tan teal thistle tomato turquoise violet
    wheat white whitesmoke yellow yellowgreen transparent currentcolor inherit
    initial unset
  ]).freeze

  def valid_css_color?(value)
    normalized = value.to_s.strip.chomp(";").strip
    # Strip CSS comments (e.g. /* Left side */)
    normalized = normalized.gsub(/\/\*.*?\*\//m, "").strip
    return false if normalized.empty?

    # Hex colors: #RGB, #RGBA, #RRGGBB, #RRGGBBAA
    return true if normalized.match?(/\A#[0-9A-Fa-f]{3,4}\z/)
    return true if normalized.match?(/\A#[0-9A-Fa-f]{6,8}\z/)

    # Single CSS function: rgb(...), hsl(...), oklch(...), linear-gradient(...), etc.
    return true if normalized.match?(/\A[\w-]+\(.*\)\z/m)

    # Multi-value CSS background: linear-gradient(...) position size repeat, ...
    # Each comma-separated layer must start with a CSS function
    if normalized.include?(",")
      layers = []
      depth = 0
      current = +""
      normalized.each_char do |char|
        case char
        when "(" then depth += 1
                      current << char
        when ")" then depth -= 1
                      current << char
        when ","
          if depth == 0
            layers << current
            current = +""
          else
            current << char
          end
        else
          current << char
        end
      end
      layers << current
      return true if layers.all? { |layer| layer.strip.match?(/\A[\w-]+\(/) }
    end

    # CSS named colors
    CSS_NAMED_COLORS.include?(normalized.downcase)
  end

  def validate_event_colors
    files = Dir.glob(Rails.root.join("data/**/event.yml"))
    color_fields = %w[banner_background featured_background featured_color]
    issues = []

    files.each do |file|
      data = YAML.load_file(file)
      relative_path = file.sub("#{Rails.root}/data/", "")

      color_fields.each do |field|
        value = data[field]
        next if value.blank?

        unless valid_css_color?(value)
          issues << {path: relative_path, field: field, value: value}
        end
      end
    end

    if issues.any?
      puts Gum.style("Events with invalid color values (#{issues.count}):", foreground: "1")
      puts

      issues.each do |issue|
        gh_action_annotation = (ENV["GITHUB_ACTIONS"] == "true") ? "::error file=data/#{issue[:path]},line=1::" : "::error::"
        puts Gum.style("❌ #{issue[:path]}", foreground: "1")
        puts "#{gh_action_annotation} #{issue[:field]}: \"#{issue[:value]}\" (not a valid CSS color)"
        puts
      end

      false
    else
      puts Gum.style("✓ All event color values are valid CSS colors", foreground: "2")
      true
    end
  end

  desc "Validate that event color fields contain valid CSS color values"
  task event_colors: :environment do
    exit 1 unless validate_event_colors
  end

  def validate_event_assets
    asset_names = %w[banner card avatar featured poster]
    assets_base = Rails.root.join("app", "assets", "images", "events")
    files = Dir.glob(Rails.root.join("data/**/event.yml"))
    issues = []

    files.each do |file|
      data = YAML.load_file(file)
      next unless data["featured_background"].present? || data["featured_color"].present?

      relative_path = file.sub("#{Rails.root}/data/", "")
      series_slug = file.split("/")[-3]
      event_slug = file.split("/")[-2]

      asset_dir = assets_base.join(series_slug, event_slug)
      missing_assets = asset_names.reject { |name| asset_dir.join("#{name}.webp").exist? }

      if missing_assets.any?
        issues << {path: relative_path, missing: missing_assets}
      end
    end

    if issues.any?
      puts Gum.style("Events with missing visual assets (#{issues.count}):", foreground: "1")
      puts

      issues.each do |issue|
        gh_action_annotation = (ENV["GITHUB_ACTIONS"] == "true") ? "::error file=data/#{issue[:path]},line=1::" : "::error::"
        puts Gum.style("❌ #{issue[:path]}", foreground: "1")
        puts "#{gh_action_annotation} Missing assets: #{issue[:missing].map { |a| "#{a}.webp" }.join(", ")}"
        puts
      end

      false
    else
      puts Gum.style("✓ All events with visual configuration have their assets", foreground: "2")
      true
    end
  end

  desc "Validate that events with visual configuration have their asset files"
  task event_assets: :environment do
    exit 1 unless validate_event_assets
  end

  desc "Validate all YAML files"
  task all: :environment do
    results = []

    puts Gum.style("Validating event.yml files", border: "rounded", padding: "0 2", margin: "1 0", border_foreground: "5")
    results << validate_files("data/**/event.yml", EventSchema, "event.yml") do |data, errors|
      is_meetup = data["kind"] == "meetup"
      unless is_meetup
        if data["start_date"].nil? || data["start_date"].to_s.strip.empty?
          errors << {"error" => "start_date is required for non-meetup events", "data_pointer" => "/start_date"}
        end
        if data["end_date"].nil? || data["end_date"].to_s.strip.empty?
          errors << {"error" => "end_date is required for non-meetup events", "data_pointer" => "/end_date"}
        end
      end
    end

    puts Gum.style("Validating series.yml files", border: "rounded", padding: "0 2", margin: "1 0", border_foreground: "5")
    results << validate_files("data/*/series.yml", SeriesSchema, "series.yml")

    puts Gum.style("Validating cfp.yml files", border: "rounded", padding: "0 2", margin: "1 0", border_foreground: "5")
    results << validate_array_files("data/**/cfp.yml", CFPSchema, "cfp.yml")

    puts Gum.style("Validating sponsors.yml files", border: "rounded", padding: "0 2", margin: "1 0", border_foreground: "5")
    results << validate_array_files("data/**/sponsors.yml", SponsorsSchema, "sponsors.yml")

    puts Gum.style("Validating venue.yml files", border: "rounded", padding: "0 2", margin: "1 0", border_foreground: "5")
    results << validate_files("data/**/venue.yml", VenueSchema, "venue.yml")

    puts Gum.style("Validating speakers.yml", border: "rounded", padding: "0 2", margin: "1 0", border_foreground: "5")
    results << validate_array_files("data/speakers.yml", SpeakerSchema, "speakers.yml")

    puts Gum.style("Validating videos.yml files", border: "rounded", padding: "0 2", margin: "1 0", border_foreground: "5")
    results << validate_array_files("data/**/videos.yml", VideoSchema, "videos.yml")

    puts Gum.style("Validating schedule.yml files", border: "rounded", padding: "0 2", margin: "1 0", border_foreground: "5")
    results << validate_files("data/**/schedule.yml", ScheduleSchema, "schedule.yml")

    puts Gum.style("Validating featured_cities.yml", border: "rounded", padding: "0 2", margin: "1 0", border_foreground: "5")
    results << validate_array_files("data/featured_cities.yml", FeaturedCitySchema, "featured_cities.yml")

    puts Gum.style("Validating involvements.yml files", border: "rounded", padding: "0 2", margin: "1 0", border_foreground: "5")
    results << validate_array_files("data/**/involvements.yml", InvolvementSchema, "involvements.yml")

    puts Gum.style("Validating transcripts.yml files", border: "rounded", padding: "0 2", margin: "1 0", border_foreground: "5")
    results << validate_array_files("data/**/transcripts.yml", TranscriptSchema, "transcripts.yml")

    puts Gum.style("Validating unique speaker slugs and GitHub handles", border: "rounded", padding: "0 2", margin: "1 0", border_foreground: "5")
    results << validate_unique_speaker_fields

    puts Gum.style("Validating unique video ids", border: "rounded", padding: "0 2", margin: "1 0", border_foreground: "5")

    all_ids = []

    Static::Video.all.each do |video|
      all_ids << video.id
      video.talks.each { |talk| all_ids << talk.id }
    end

    duplicates = all_ids.tally.select { |_id, count| count > 1 }

    if duplicates.any?
      puts Gum.style("Duplicate video ids found (#{duplicates.count}):", foreground: "1")
      puts

      duplicates.each do |id, count|
        puts Gum.style("❌ #{id} (#{count} occurrences)", foreground: "1")
      end

      puts

      results << false
    else
      puts Gum.style("✓ All video ids are unique", foreground: "2")

      results << true
    end

    puts Gum.style("Validating YouTube videos have published_at", border: "rounded", padding: "0 2", margin: "1 0", border_foreground: "5")

    missing_published_at = []

    Static::Video.all.each do |video|
      if video.video_provider == "youtube" && (video.published_at.blank? || video.published_at == "TODO")
        missing_published_at << video
      end

      video.talks.each do |talk|
        if talk.video_provider == "youtube" && (talk.published_at.blank? || talk.published_at == "TODO")
          missing_published_at << talk
        end
      end
    end

    if missing_published_at.any?
      puts Gum.style("YouTube videos missing published_at date (#{missing_published_at.count}):", foreground: "1")
      puts

      missing_published_at.each do |video|
        puts Gum.style("❌ #{video.id} (#{video.title})", foreground: "1")
      end

      puts

      results << false
    else
      puts Gum.style("✓ All YouTube videos have a published_at date", foreground: "2")

      results << true
    end

    if Rails.env.development?
      puts Gum.style("Validating speaker duplicates", border: "rounded", padding: "0 2", margin: "1 0", border_foreground: "5")
      results << validate_speaker_duplicates
    end

    puts Gum.style("Validating event city names", border: "rounded", padding: "0 2", margin: "1 0", border_foreground: "5")
    results << validate_event_city_names

    puts Gum.style("Validating video city names", border: "rounded", padding: "0 2", margin: "1 0", border_foreground: "5")
    results << validate_video_city_names

    puts Gum.style("Validating event color values", border: "rounded", padding: "0 2", margin: "1 0", border_foreground: "5")
    results << validate_event_colors

    puts Gum.style("Validating event visual assets", border: "rounded", padding: "0 2", margin: "1 0", border_foreground: "5")
    results << validate_event_assets

    puts
    if results.all?
      puts Gum.style("All validations passed!", border: "rounded", padding: "0 2", foreground: "2", border_foreground: "2")
    else
      puts Gum.style("Some validations failed", border: "rounded", padding: "0 2", foreground: "1", border_foreground: "1")
    end

    exit 1 unless results.all?
  end
end
