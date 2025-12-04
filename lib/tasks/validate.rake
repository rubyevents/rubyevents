# frozen_string_literal: true

namespace :validate do
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
      puts "Invalid #{file_type} files (#{invalid_files.count}):\n\n"
      invalid_files.each do |file|
        puts "❌ #{file[:path]}:"
        file[:errors].each { |e| puts "   #{e["error"]} at #{e["data_pointer"]}" }
        puts
      end
    end

    puts "#{file_type}: #{valid_count} valid, #{invalid_files.count} invalid out of #{files.count} files"
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
      puts "Invalid #{file_type} files (#{invalid_files.count}):\n\n"
      invalid_files.each do |file|
        puts "❌ #{file[:path]}:"
        file[:errors].first(10).each { |e| puts "   #{e["error"]} at #{e["data_pointer"]}" }
        puts "   ... and #{file[:errors].count - 10} more errors" if file[:errors].count > 10
        puts
      end
    end

    puts "#{file_type}: #{valid_count} valid, #{invalid_files.count} invalid out of #{files.count} files"
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
      puts "Duplicate video ids found (#{duplicates.count}):\n\n"

      duplicates.each do |id, count|
        puts "❌ #{id} (#{count} occurrences)"
      end

      puts

      exit 1
    else
      puts "All video ids are unique"
    end
  end

  desc "Validate all YAML files"
  task all: :environment do
    results = []

    puts "=" * 60
    puts "Validating event.yml files..."
    puts "=" * 60
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

    puts "\n" + "=" * 60
    puts "Validating series.yml files..."
    puts "=" * 60
    results << validate_files("data/*/series.yml", SeriesSchema, "series.yml")

    puts "\n" + "=" * 60
    puts "Validating venue.yml files..."
    puts "=" * 60
    results << validate_files("data/**/venue.yml", VenueSchema, "venue.yml")

    puts "\n" + "=" * 60
    puts "Validating videos.yml files..."
    puts "=" * 60
    results << validate_array_files("data/**/videos.yml", VideoSchema, "videos.yml")

    puts "\n" + "=" * 60
    puts "Validating schedule.yml files..."
    puts "=" * 60
    results << validate_files("data/**/schedule.yml", ScheduleSchema, "schedule.yml")

    puts "\n" + "=" * 60
    puts "Validating unique video ids..."
    puts "=" * 60

    all_ids = []

    Static::Video.all.each do |video|
      all_ids << video.id
      video.talks.each { |talk| all_ids << talk.id }
    end

    duplicates = all_ids.tally.select { |_id, count| count > 1 }

    if duplicates.any?
      puts "Duplicate video ids found (#{duplicates.count}):\n\n"

      duplicates.each do |id, count|
        puts "❌ #{id} (#{count} occurrences)"
      end

      puts

      results << false
    else
      puts "All video ids are unique"

      results << true
    end

    puts "\n" + "=" * 60
    puts "Overall: #{results.all? ? "All validations passed!" : "Some validations failed"}"
    puts "=" * 60

    exit 1 unless results.all?
  end
end
