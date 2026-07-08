# frozen_string_literal: true

require "gum"
require "parallel"

namespace :validate do
  def collect_validator_errors(files:, validators:)
    return {} if files.empty? || validators.empty?

    validators.each { |validator_class| validator_class.warmup if validator_class.respond_to?(:warmup) }

    worker_count = [files.size, Parallel.processor_count].min

    Parallel.map(files, in_processes: worker_count) do |file|
      document = parse_document(file)

      validators.flat_map { |validator_class| validator_class.new(file_path: file, document: document).errors }
    end.flatten.group_by(&:file_path)
  end

  def parse_document(file)
    return nil unless file.to_s.end_with?(".yml")

    Yerba.parse_file(file)
  rescue
    nil
  end

  def print_validator_errors(file_errors, warning_only: false)
    file_errors.each do |file, errors|
      puts Gum.style(file, foreground: (warning_only ? "3" : "1"))

      errors.each do |error|
        puts warning_only ? error.as_warning : error.as_error
      end

      puts
    end
  end

  def validate_files(files:, validators:, success_message:, warning_only: false)
    file_errors = collect_validator_errors(files:, validators:)

    if file_errors.empty?
      puts Gum.style(success_message, foreground: "2")
    else
      print_validator_errors(file_errors, warning_only:)
    end

    file_errors.values.flatten
  end

  def validate_event_files
    validate_files(
      files: Dir.glob(Rails.root.join("data/**/event.yml")),
      validators: Static::Validators::Validator.event_validator_classes,
      success_message: "✓ All event.yml files passed validations!"
    )
  end

  desc "Validate event.yml files"
  task events: :environment do
    errors = validate_event_files

    if errors.any? { |error| error.message.include?("recordings_published_date") }
      puts
      puts Gum.style("To fix recordings_published_date issues:", foreground: "3")
      puts Gum.style("  • bin/rails event_recordings_published_date:fix  # reconcile event.yml recordings_published_date", foreground: "3")
      puts Gum.style("  • bin/rails youtube:sync_published_at            # correct video dates first (needs a YouTube API key)", foreground: "3")
    end

    exit 1 if errors.any?
  end

  def validate_series_files
    validate_files(
      files: Dir.glob(Rails.root.join("data/**/series.yml")),
      validators: Static::Validators::Validator.series_validator_classes,
      success_message: "✓ All series.yml files passed validations!"
    )
  end

  desc "Validate series.yml files"
  task series: :environment do
    exit 1 if validate_series_files.any?
  end

  def validate_venue_files
    validate_files(
      files: Dir.glob(Rails.root.join("data/**/venue.yml")),
      validators: [],
      success_message: "✓ All venue.yml files passed validations!"
    )
  end

  desc "Validate venue.yml files"
  task venues: :environment do
    exit 1 if validate_venue_files.any?
  end

  def validate_speakers_file
    validate_files(
      files: Dir.glob(Rails.root.join("data/speakers.yml")),
      validators: Static::Validators::Validator.speaker_validator_classes,
      success_message: "✓ data/speakers.yml passed validations!"
    )
  end

  desc "Validate data/speakers.yml"
  task speakers: :environment do
    exit 1 if validate_speakers_file.any?
  end

  desc "Validate data/**/involvements.yml"
  task involvements: :environment do
    exit 1 if validate_involvements_file.any?
  end

  def validate_involvements_file
    validate_files(
      files: Dir.glob(Rails.root.join("data/**/involvements.yml")),
      validators: Static::Validators::Validator.involvement_validator_classes,
      success_message: "✓ data/**/involvements.yml passed validations!"
    )
  end

  def validate_video_files
    validate_files(
      files: Dir.glob(Rails.root.join("data/**/videos.yml")),
      validators: Static::Validators::Validator.video_validator_classes,
      success_message: "✓ All videos.yml files passed validations!"
    )
  end

  desc "Validate videos.yml files"
  task videos: :environment do
    exit 1 if validate_video_files.any?
  end

  # Validates videos.yml
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

  def validate_unique_video_ids
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

      false
    else
      puts Gum.style("✓ All video ids are unique", foreground: "2")

      true
    end
  end

  desc "Validate that all Static::Video records have unique ids"
  task unique_video_ids: :environment do
    exit 1 unless validate_unique_video_ids
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

  def validate_video_city_names
    alias_to_canonical = Static::City.alias_lookup
    files = Dir.glob(Rails.root.join("data/**/videos.yml"))
    issues = []

    files.each do |file|
      data = Yerba.parse_file(file).to_a
      relative_path = file.sub("#{Rails.root}/", "")

      Array(data).each_with_index do |video, index|
        location = video["location"]

        next if location.blank?

        city_part = location.split(",").first&.strip

        next if city_part.blank?
        next if city_part.downcase == "online" || city_part.downcase == "remote"

        canonical = alias_to_canonical[city_part.downcase]&.name

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

  def validate_data_files
    validate_files(
      files: Dir.glob(Rails.root.join("data/**/*"), File::FNM_DOTMATCH).select { |file| File.file?(file) },
      validators: [
        Static::Validators::ExpectedDataFiles
      ],
      success_message: "✓ All data files are in expected locations!"
    )
  end

  desc "Validate that data/ only contains expected files at expected nesting levels"
  task data_files: :environment do
    exit 1 if validate_data_files.any?
  end

  def validate_event_assets
    validate_files(
      files: Dir.glob(Rails.root.join("app/assets/images/events/**/*.webp")),
      validators: [
        Static::Validators::AssetDimensions,
        Static::Validators::OrphanedEventAssets
      ],
      success_message: "✓ All event assets passed validations!"
    )
  end

  desc "Warn when event assets do not match expected dimensions"
  task event_assets: :environment do
    exit 1 if validate_event_assets.any?
  end

  def validate_thumbnails
    validate_files(
      files: Dir.glob(Rails.root.join("app/assets/images/thumbnails/**/*.webp")),
      validators: [
        Static::Validators::RedundantThumbnails
      ],
      success_message: "✓ No redundant thumbnails found!"
    )
  end

  desc "Validate that thumbnails are not redundant (no orphaned thumbnail files)"
  task thumbnails: :environment do
    exit 1 if validate_thumbnails.any?
  end

  desc "Validate all city-related data"
  task cities: [:event_city_names, :video_city_names]

  def run_yerba_check
    output = `bundle exec yerba check 2>&1`

    if $?.success?
      puts Gum.style("✓ All Yerbafile rules passed", foreground: "2")

      true
    else
      puts output

      if output.include?("published_at")
        puts Gum.style("Hint: Run 'rails youtube:fetch_published_at' to fetch missing published_at dates from YouTube", foreground: "3")
        puts
      end

      false
    end
  end

  def validate_speakers_in_sync
    speakers = Static::SpeakersFile.new
    missing = speakers.missing_speakers
    orphaned = speakers.orphaned_speakers

    if missing.empty? && orphaned.empty?
      puts Gum.style("✓ speakers.yml is in sync", foreground: "2")

      true
    else
      if missing.any?
        puts Gum.style("#{missing.length} speakers referenced in videos but missing from speakers.yml:", foreground: "1")
        missing.sort.each { |name| puts Gum.style("  ❌ #{name}", foreground: "1") }
        puts
      end

      if orphaned.any?
        puts Gum.style("#{orphaned.length} orphaned speakers in speakers.yml:", foreground: "1")
        orphaned.sort.each { |name| puts Gum.style("  ❌ #{name}", foreground: "1") }
        puts
      end

      puts Gum.style("Run: rails speakers_file:sync", foreground: "3")

      false
    end
  end

  desc "Validate all YAML files"
  task all: :environment do
    sections = {
      "Running yerba check (schemas, formatting, uniqueness)" => -> { run_yerba_check },
      "Validating videos.yml files" => -> { validate_video_files.none? },
      "Validating event.yml files" => -> { validate_event_files.none? },
      "Validating series.yml files" => -> { validate_series_files.none? },
      "Validating venue.yml files" => -> { validate_venue_files.none? },
      "Validating speakers.yml file" => -> { validate_speakers_file.none? },
      "Validating involvements.yml file" => -> { validate_involvements_file.none? },
      "Validating speakers.yml is in sync" => -> { validate_speakers_in_sync },
      "Validating data file locations" => -> { validate_data_files.none? },
      "Validating unique video ids" => -> { validate_unique_video_ids },
      "Validating SpeakerDeck slides URLs" => -> { validate_speakerdeck_urls },
      "Validating SpeakerDeck handles" => -> { validate_speakerdeck_handles },
      "Validating video city names" => -> { validate_video_city_names },
      "Validating event asset dimensions" => -> { validate_event_assets.none? },
      "Validating redundant thumbnails" => -> { validate_thumbnails.none? }
    }

    passed = if $stdout.tty? && ENV["VALIDATE_TUI"] != "0"
      run_sections_with_tui(sections)
    else
      run_sections_with_text_output(sections)
    end

    puts
    if passed
      puts Gum.style("All validations passed!", border: "rounded", padding: "0 2", foreground: "2", border_foreground: "2")
    else
      puts Gum.style("Some validations failed", border: "rounded", padding: "0 2", foreground: "1", border_foreground: "1")
    end

    exit 1 unless passed
  end

  def run_sections_with_tui(sections)
    require_relative "../validate/tui"

    passed, failures = Validate::TUI.run(sections)

    failures.each do |title, output|
      puts Gum.style(title, border: "rounded", padding: "0 2", margin: "1 0", border_foreground: "1")
      puts output
    end

    passed
  end

  def run_sections_with_text_output(sections)
    print_mutex = Mutex.new

    on_finish = ->(title, _index, result) {
      print_mutex.synchronize do
        puts Gum.style(title, border: "rounded", padding: "0 2", margin: "1 0", border_foreground: "5")
        puts result[1]
      end
    }

    color = $stdout.tty?

    results = Parallel.map(sections.keys, in_processes: sections.size, finish: on_finish) do |title|
      ENV["CLICOLOR_FORCE"] = "1" if color

      captured = StringIO.new
      original, $stdout = $stdout, captured

      begin
        [sections.fetch(title).call, captured.string]
      ensure
        $stdout = original
      end
    end

    results.all? { |section_passed, _output| section_passed }
  end
end
