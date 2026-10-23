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

  # Record validations, declared on the Static models

  def validated_models
    Rails.autoloaders.main.eager_load_dir(Rails.root.join("app/models/static"))

    Yerba::Record.validated_models
  end

  def record_errors(models)
    Yerba::Record.validate_all(models).map do |error|
      record = error.base
      location = record.error_location(error)

      [Static::Validators::Error.new(error.full_message, file_path: record.error_file_path(error), location: location), record.error_warning?(error)]
    end
  end

  def validate_records(models, success_message:)
    warnings, errors = record_errors(models).partition(&:last).map { |pairs| pairs.map(&:first) }

    print_validator_errors(warnings.group_by(&:file_path), warning_only: true)
    print_validator_errors(errors.group_by(&:file_path))

    puts Gum.style(success_message, foreground: "2") if errors.empty?

    errors
  end

  def record_tasks
    {
      events: {models: %w[Static::Event], files: "event.yml files"},
      series: {models: %w[Static::EventSeries], files: "series.yml files"},
      videos: {models: %w[Static::Talk Static::Talk::AlternativeRecording], files: "videos.yml files"},
      speakers: {models: %w[Static::Speaker], files: "data/speakers.yml"},
      involvements: {models: %w[Static::Involvement], files: "involvements.yml files"},
      schedules: {models: %w[Static::Schedule], files: "schedule.yml files"},
      sponsors: {models: %w[Static::Sponsor::Entry], files: "sponsors.yml files"},
      event_assets: {models: %w[Static::EventAsset], files: "event assets"},
      thumbnails: {models: %w[Static::Thumbnail], files: "thumbnails"}
    }
  end

  def recordings_published_date_hint(errors)
    return unless errors.any? { |error| error.message.include?("recordings_published_date") }

    puts
    puts Gum.style("To fix recordings_published_date issues:", foreground: "3")
    puts Gum.style("  • bin/rails event_recordings_published_date:fix  # reconcile event.yml recordings_published_date", foreground: "3")
    puts Gum.style("  • bin/rails youtube:sync_published_at            # correct video dates first (needs a YouTube API key)", foreground: "3")
  end

  record_tasks.each do |name, task_options|
    desc "Validate #{task_options[:files]}"
    task name => :environment do
      models = task_options[:models].map(&:constantize)
      errors = validate_records(models, success_message: "✓ All #{task_options[:files]} passed validations!")
      errors += validate_talk_renames if name == :videos
      recordings_published_date_hint(errors) if name == :events

      exit 1 if errors.any?
    end
  end

  desc "Validate every record with the validations declared on its Static model"
  task records: :environment do
    exit 1 if validate_records(validated_models, success_message: "✓ All records passed validations!").any?
  end

  # Checks that aren't about a single record

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
      validators: [Static::Validators::ExpectedDataFiles],
      success_message: "✓ All data files are in expected locations!"
    )
  end

  desc "Validate that data/ only contains expected files at expected nesting levels"
  task data_files: :environment do
    exit 1 if validate_data_files.any?
  end

  def validate_talk_renames
    validate_files(
      files: Dir.glob(Static::Talk.file_glob),
      validators: [Static::Validators::TalkRenames],
      success_message: "✓ No talk ids disappeared without an old_id!"
    )
  end

  desc "Validate that talk ids which disappeared from a videos.yml are kept as an old_id or listed in removed_talk_ids"
  task talk_renames: :environment do
    exit 1 if validate_talk_renames.any?
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
    fixes = Yerba::Record.fix_all(models: validated_models)

    fixes.each do |record, validator, changes|
      puts "#{record.project_file_path}: #{validator.class.name.demodulize} fixed #{changes}"
    end

    changed = fixes.sum(&:last)
    fixed_files = fixes.map { |record, _validator, _changes| record.file_path }.uniq.size

    puts
    puts Gum.style(changed.zero? ? "✓ Nothing to fix" : "Fixed #{changed} issue(s) across #{fixed_files} file(s)", foreground: "2")
    puts Gum.style("Run bin/rails validate:all to confirm", foreground: "3") if changed.positive?
  end

  desc "Validate all YAML files"
  task all: :environment do
    ENV["VALIDATE_FILE_WORKERS"] ||= [Parallel.processor_count / 2, 2].max.to_s

    # The slowest sections come first so they start as early as possible, the rest are alphabetized
    record_sections = record_tasks.to_h do |_name, task_options|
      models = task_options[:models].map(&:constantize)

      ["Validating #{task_options[:files]}", -> { validate_records(models, success_message: "✓ All #{task_options[:files]} passed validations!").none? }]
    end

    other_models = validated_models - record_tasks.values.flat_map { |task_options| task_options[:models] }.map(&:constantize)

    if other_models.any?
      record_sections["Validating other records"] = -> { validate_records(other_models, success_message: "✓ All other records passed validations!").none? }
    end

    sections = {
      "Validating videos.yml files" => record_sections.delete("Validating videos.yml files"),
      "Validating speakers.yml is in sync" => -> { validate_speakers_in_sync },
      "Running yerba check (schemas, formatting, uniqueness)" => -> { run_yerba_check },
      "Validating talk renames" => -> { validate_talk_renames.none? },
      "Validating data file locations" => -> { validate_data_files.none? },
      "Validating SpeakerDeck handles" => -> { validate_speakerdeck_handles },
      "Validating SpeakerDeck slides URLs" => -> { validate_speakerdeck_urls },
      **record_sections.sort.to_h
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
