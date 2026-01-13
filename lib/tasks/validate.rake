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
        file[:errors].each { |e| puts "   #{e["error"]} at #{e["data_pointer"]}" }
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
        file[:errors].first(10).each { |e| puts "   #{e["error"]} at #{e["data_pointer"]}" }
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

  desc "Validate all venue.yml files against VenueSchema"
  task venues: :environment do
    success = validate_files("data/**/venue.yml", VenueSchema, "venue.yml")
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

    puts Gum.style("Validating venue.yml files", border: "rounded", padding: "0 2", margin: "1 0", border_foreground: "5")
    results << validate_files("data/**/venue.yml", VenueSchema, "venue.yml")

    puts Gum.style("Validating videos.yml files", border: "rounded", padding: "0 2", margin: "1 0", border_foreground: "5")
    results << validate_array_files("data/**/videos.yml", VideoSchema, "videos.yml")

    puts Gum.style("Validating schedule.yml files", border: "rounded", padding: "0 2", margin: "1 0", border_foreground: "5")
    results << validate_files("data/**/schedule.yml", ScheduleSchema, "schedule.yml")

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

    puts
    if results.all?
      puts Gum.style("All validations passed!", border: "rounded", padding: "0 2", foreground: "2", border_foreground: "2")
    else
      puts Gum.style("Some validations failed", border: "rounded", padding: "0 2", foreground: "1", border_foreground: "1")
    end

    exit 1 unless results.all?
  end
end
