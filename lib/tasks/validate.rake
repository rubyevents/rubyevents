# frozen_string_literal: true

require "gum"

namespace :validate do
  def validate_event_dates
    files = Dir.glob(Rails.root.join("data/**/event.yml"))
    errors = []

    files.each do |file|
      file_errors = Static::Validators::EventDates.new(file_path: file).errors
      next if file_errors.empty?

      relative_path = file.sub("#{Rails.root}/", "")
      puts Gum.style("❌ #{relative_path}", foreground: "1")
      file_errors.each { |e| puts e.as_error }
      puts
      errors.concat(file_errors)
    end

    errors
  end

  desc "Validate start_date and end_date are present for non-meetup event.yml files"
  task event_dates: :environment do
    exit 1 if validate_event_dates.any?
  end

  def validate_speakers
    file = Rails.root.join("data/speakers.yml").to_s
    errors = Static::Validators::UniqueSpeakerFields.new(file_path: file).errors

    if errors.empty?
      puts Gum.style("✓ All speaker fields are unique!", foreground: "2")
    else
      errors.each { |e| puts e.as_error }
    end

    errors
  end

  desc "Validate data/speakers.yml"
  task speakers: :environment do
    exit 1 if validate_speakers.any?
  end

  def validate_speakers_in_videos
    errors = Static::Validators::SpeakerExists.errors

    if errors.any?
      puts Gum.style("Speakers referenced in videos.yml but missing from speakers.yml (#{errors.count}):", foreground: "1")
      puts
      errors.each { |e| puts e.as_error }
      puts
      puts Gum.style("Run: rails speakers_file:sync", foreground: "3")
    else
      puts Gum.style("✓ All speakers in videos.yml exist in speakers.yml", foreground: "2")
    end
    errors
  end

  desc "Validate that all speakers in videos.yml exist in speakers.yml"
  task speakers_in_videos: :environment do
    exit 1 if validate_speakers_in_videos.any?
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

  def validate_speaker_duplicates
    speakers_file = Static::SpeakersFile.new
    passed = true

    same = speakers_file.same_name_duplicates

    if same.any?
      puts Gum.style("Same name duplicates (#{same.count}):", foreground: "1")

      same.each do |name, count|
        puts Gum.style("  ❌ #{name} (#{count} occurrences)", foreground: "1")
      end

      puts
      passed = false
    end

    reversed = speakers_file.reversed_name_duplicates

    if reversed.any?
      puts Gum.style("Reversed name duplicates (#{reversed.count} pairs):", foreground: "1")

      reversed.each do |pair|
        puts Gum.style("  ❌ #{pair[0]} ↔ #{pair[1]}", foreground: "1")
      end

      puts
      passed = false
    end

    if passed
      puts Gum.style("✓ No speaker duplicates found", foreground: "2")
    end

    passed
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
        relative_path = file.sub("#{Rails.root}/", "")

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
      relative_path = file.sub("#{Rails.root}/", "")

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

  def validate_speakerdeck_urls
    issues = Speakerdeck::SlidesScanner.new.problematic_urls

    if issues.any?
      puts Gum.style("Problematic SpeakerDeck slides URLs (#{issues.count}):", foreground: "1")
      puts

      issues.each do |issue|
        gh_annotation = (ENV["GITHUB_ACTIONS"] == "true") ? "::error file=data/#{issue[:path]},line=1::" : "::error::"
        puts Gum.style("❌ #{issue[:path]}", foreground: "1")
        puts " #{gh_annotation} #{issue[:label]}: #{issue[:url]}"
        puts
      end

      false
    else
      puts Gum.style("✓ All SpeakerDeck slides URLs are valid", foreground: "2")
      true
    end
  end

  desc "Validate SpeakerDeck slides URLs"
  task speakerdeck_urls: :environment do
    exit 1 unless validate_speakerdeck_urls
  end

  desc "Validate all city-related data"
  task cities: [:event_city_names, :video_city_names]

  def validate_assets_if_colors_configured
    files = Dir.glob(Rails.root.join("data/**/event.yml"))
    errors = files.flat_map { |f| Static::Validators::ColorsHaveAssets.new(file_path: f).errors }

    if errors.any?
      puts Gum.style("Events with visual config but no assets (#{errors.count}):", foreground: "1")
      puts
      errors.each { |e| puts e.as_error }
      puts
    else
      puts Gum.style("✓ All events with visual configuration have their assets", foreground: "2")
    end

    errors
  end

  desc "Validate that events with visual configuration have their asset files"
  task event_assets: :environment do
    exit 1 if validate_assets_if_colors_configured.any?
  end

  desc "Validate all YAML files"
  task all: :environment do
    results = []

    puts Gum.style("Running yerba check (schemas, formatting, uniqueness)", border: "rounded", padding: "0 2", margin: "1 0", border_foreground: "5")
    yerba_passed = system("bundle exec yerba check")
    results << yerba_passed

    if yerba_passed
      puts Gum.style("✓ All Yerbafile rules passed", foreground: "2")
    end

    puts Gum.style("Validating event dates", border: "rounded", padding: "0 2", margin: "1 0", border_foreground: "5")
    results << validate_event_dates.none?

    puts Gum.style("Validating unique speaker fields", border: "rounded", padding: "0 2", margin: "1 0", border_foreground: "5")
    results << validate_speakers.none?

    puts Gum.style("Validating speakers in videos.yml exist in speakers.yml", border: "rounded", padding: "0 2", margin: "1 0", border_foreground: "5")
    results << validate_speakers_in_videos.none?

    puts Gum.style("Validating speakers.yml is in sync", border: "rounded", padding: "0 2", margin: "1 0", border_foreground: "5")
    speakers = Static::SpeakersFile.new
    orphaned = speakers.orphaned_speakers

    if orphaned.empty?
      puts Gum.style("✓ speakers.yml is in sync", foreground: "2")
      results << true
    else
      if orphaned.any?
        puts Gum.style("#{orphaned.length} orphaned speakers in speakers.yml:", foreground: "1")
        orphaned.sort.each { |name| puts Gum.style("  ❌ #{name}", foreground: "1") }
        puts
      end

      puts Gum.style("Run: rails speakers_file:sync", foreground: "3")

      results << false
    end

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

    puts Gum.style("Validating speaker duplicates", border: "rounded", padding: "0 2", margin: "1 0", border_foreground: "5")
    results << validate_speaker_duplicates

    puts Gum.style("Validating SpeakerDeck slides URLs", border: "rounded", padding: "0 2", margin: "1 0", border_foreground: "5")
    results << validate_speakerdeck_urls

    puts Gum.style("Validating SpeakerDeck handles", border: "rounded", padding: "0 2", margin: "1 0", border_foreground: "5")
    results << validate_speakerdeck_handles

    puts Gum.style("Validating event city names", border: "rounded", padding: "0 2", margin: "1 0", border_foreground: "5")
    results << validate_event_city_names

    puts Gum.style("Validating video city names", border: "rounded", padding: "0 2", margin: "1 0", border_foreground: "5")
    results << validate_video_city_names

    puts Gum.style("Validating event visual assets", border: "rounded", padding: "0 2", margin: "1 0", border_foreground: "5")
    results << validate_assets_if_colors_configured.none?

    puts
    if results.all?
      puts Gum.style("All validations passed!", border: "rounded", padding: "0 2", foreground: "2", border_foreground: "2")
    else
      puts Gum.style("Some validations failed", border: "rounded", padding: "0 2", foreground: "1", border_foreground: "1")
    end

    exit 1 unless results.all?
  end
end
