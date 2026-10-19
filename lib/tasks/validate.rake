# frozen_string_literal: true

require "gum"
require "open3"
require "parallel"

namespace :validate do
  # Helpers for validating one set of data files
  def collect_validator_errors(files:, validators:)
    return {} if files.empty? || validators.empty?

    validators.each { |validator_class| validator_class.warmup if validator_class.respond_to?(:warmup) }

    worker_count = [files.size, file_worker_count].min

    Parallel.map(files, in_processes: worker_count) do |file|
      document = parse_document(file)

      validators.flat_map { |validator_class| validator_class.new(file_path: file, document: document).errors }
    end.flatten.group_by(&:file_path)
  end

  def file_worker_count
    override = ENV["VALIDATE_FILE_WORKERS"].to_i

    (override > 0) ? override : Parallel.processor_count
  end

  def parse_document(file)
    return nil unless file.to_s.end_with?(".yml")

    Yerba.parse_file(file.to_s)
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

  # File-level validations

  def validate_cfp_files
    validate_files(
      files: Dir.glob(Static::CFP.file_glob),
      validators: Static::Validators::Validator.cfp_validator_classes,
      success_message: "✓ All cfp.yml files passed validations!"
    )
  end

  desc "Validate cfp.yml files"
  task cfps: :environment do
    exit 1 if validate_cfp_files.any?
  end

  def reject_git_ignored(files)
    return files if files.empty?

    output, status = Open3.capture2("git", "check-ignore", "--stdin", stdin_data: files.join("\n"))
    return files unless [0, 1].include?(status.exitstatus)

    files - output.split("\n")
  rescue
    files
  end

  def validate_data_files
    files = Dir.glob(Rails.root.join("data/**/*"), File::FNM_DOTMATCH).select { |file| File.file?(file) }

    validate_files(
      files: reject_git_ignored(files),
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
      validators: Static::Validators::Validator.event_assets_validator_classes,
      success_message: "✓ All event assets passed validations!"
    )
  end

  desc "Warn when event assets do not match expected dimensions"
  task event_assets: :environment do
    exit 1 if validate_event_assets.any?
  end

  def validate_event_files
    validate_files(
      files: Dir.glob(Static::Event.file_glob),
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

  def validate_involvements_file
    validate_files(
      files: Dir.glob(Static::Involvement.file_glob),
      validators: Static::Validators::Validator.involvement_validator_classes,
      success_message: "✓ data/**/involvements.yml passed validations!"
    )
  end

  desc "Validate data/**/involvements.yml"
  task involvements: :environment do
    exit 1 if validate_involvements_file.any?
  end

  def validate_schedule_files
    validate_files(
      files: Dir.glob(Static::Schedule.file_glob),
      validators: Static::Validators::Validator.schedule_validator_classes,
      success_message: "✓ All schedule.yml files passed validations!"
    )
  end

  desc "Validate schedule.yml files"
  task schedules: :environment do
    exit 1 if validate_schedule_files.any?
  end

  def validate_series_files
    validate_files(
      files: Dir.glob(Static::EventSeries.file_glob),
      validators: Static::Validators::Validator.series_validator_classes,
      success_message: "✓ All series.yml files passed validations!"
    )
  end

  desc "Validate series.yml files"
  task series: :environment do
    exit 1 if validate_series_files.any?
  end

  # TODO - migrate to validator
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

  def validate_speakers_file
    validate_files(
      files: [Static::Speaker.file_path],
      validators: Static::Validators::Validator.speaker_validator_classes,
      success_message: "✓ data/speakers.yml passed validations!"
    )
  end

  desc "Validate data/speakers.yml"
  task speakers: :environment do
    exit 1 if validate_speakers_file.any?
  end

  def validate_speakers_in_sync
    speakers = Static::Speaker.all
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

  def validate_sponsor_files
    validate_files(
      files: Dir.glob(Static::Sponsor.file_glob),
      validators: Static::Validators::Validator.sponsor_validator_classes,
      success_message: "✓ All sponsors.yml files passed validations!"
    )
  end

  desc "Validate sponsors.yml files"
  task sponsors: :environment do
    exit 1 if validate_sponsor_files.any?
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

  def validate_venue_files
    validate_files(
      files: Dir.glob(Static::Venue.file_glob),
      validators: [],
      success_message: "✓ All venue.yml files passed validations!"
    )
  end

  desc "Validate venue.yml files"
  task venues: :environment do
    exit 1 if validate_venue_files.any?
  end

  def validate_video_files
    validate_files(
      files: Dir.glob(Static::Talk.file_glob),
      validators: Static::Validators::Validator.video_validator_classes,
      success_message: "✓ All videos.yml files passed validations!"
    )
  end

  desc "Validate videos.yml files"
  task videos: :environment do
    exit 1 if validate_video_files.any?
  end

  # End individual file validations

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

  def run_sections_with_tui(sections)
    require_relative "../validate/tui"

    passed, failures = Validate::TUI.run(sections)

    failures.each do |title, output|
      puts Gum.style(title, border: "rounded", padding: "0 2", margin: "1 0", border_foreground: "1")
      puts output
    end

    passed
  end

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

  desc "Fix the issues that validators know how to fix automatically"
  task fix: :environment do
    validator_classes = Static::Validators::Validator.fixable_validators
    changed = 0
    fixed_files = 0

    Dir.glob(Rails.root.join("data/**/*.yml")).sort.each do |path|
      document = parse_document(path)
      next unless document

      validator_classes.each do |validator_class|
        validator = validator_class.new(file_path: path, document: document)
        next unless validator.applicable?

        result = validator.fix
        next unless result

        changed += result[:changed]
        fixed_files += 1

        puts "#{path.to_s.sub("#{Rails.root}/", "")}: #{validator_class.name.demodulize} fixed #{result[:changed]}"
      end
    end

    puts
    puts Gum.style(changed.zero? ? "✓ Nothing to fix" : "Fixed #{changed} issue(s) across #{fixed_files} file(s)", foreground: "2")
    puts Gum.style("Run bin/rails validate:all to confirm", foreground: "3") if changed.positive?
  end

  desc "Validate all YAML files"
  task all: :environment do
    ENV["VALIDATE_FILE_WORKERS"] ||= [Parallel.processor_count / 2, 2].max.to_s

    # The two slowest sections come first so they start as early as possible,
    # the rest are alphabetized
    sections = {
      "Validating videos.yml files" => -> { validate_video_files.none? },
      "Validating speakers.yml is in sync" => -> { validate_speakers_in_sync },
      "Running yerba check (schemas, formatting, uniqueness)" => -> { run_yerba_check },
      "Validating cfp.yml files" => -> { validate_cfp_files.none? },
      "Validating data file locations" => -> { validate_data_files.none? },
      "Validating event asset dimensions" => -> { validate_event_assets.none? },
      "Validating event.yml files" => -> { validate_event_files.none? },
      "Validating involvements.yml file" => -> { validate_involvements_file.none? },
      "Validating redundant thumbnails" => -> { validate_thumbnails.none? },
      "Validating schedule.yml files" => -> { validate_schedule_files.none? },
      "Validating series.yml files" => -> { validate_series_files.none? },
      "Validating SpeakerDeck handles" => -> { validate_speakerdeck_handles },
      "Validating SpeakerDeck slides URLs" => -> { validate_speakerdeck_urls },
      "Validating speakers.yml file" => -> { validate_speakers_file.none? },
      "Validating sponsors.yml files" => -> { validate_sponsor_files.none? },
      "Validating venue.yml files" => -> { validate_venue_files.none? }
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
end
