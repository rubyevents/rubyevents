# frozen_string_literal: true

module Static
  class DataImporter
    GLOBAL_MODELS = [Static::City, Static::Speaker, Static::Topic].freeze

    EVENT_FILE_IMPORTS = {
      Static::Talk => :import_videos!,
      Static::Sponsor => :import_sponsors!,
      Static::CFP => :import_cfps!,
      Static::Involvement => :import_involvements!
    }.freeze

    def self.phases
      [
        [Static::City],
        [Static::Speaker],
        [Static::EventSeries],
        [Static::Event],
        [Static::Venue],
        EVENT_FILE_IMPORTS.keys,
        [Static::Topic]
      ]
    end

    def self.import(path, reload: false)
      absolute = Rails.root.join(ImportedFile.relative_path(path)).to_s
      model = model_for(absolute)
      return false unless model

      reload_caches_for(model) if reload

      folder = File.basename(File.dirname(absolute))

      if model.in?(GLOBAL_MODELS)
        model.import_all!

        true
      elsif model == Static::EventSeries
        series = Static::EventSeries.find_by_slug(folder)
        return false unless series

        series.import_series!
        true
      elsif model.in?([Static::Event, Static::Venue])
        event = Static::Event.find_by_slug(folder)
        return false unless event

        event.import_event!
        true
      elsif model == Static::Schedule
        true
      else
        with_event(folder) { |static, record| static.public_send(EVENT_FILE_IMPORTS.fetch(model), record) }
      end
    end

    def self.seed_changed!(reload: false, force: false, logger: nil)
      log = logger || method(:puts)
      imported = 0
      skipped = 0

      seed_phases.each do |paths|
        paths.each do |path|
          relative = ImportedFile.relative_path(path)

          unless force || ImportedFile.changed?(relative)
            skipped += 1
            next
          end

          if import(relative, reload: reload)
            ImportedFile.record!(relative)
            imported += 1
            log.call("imported #{relative}")
          end
        rescue => e
          log.call("error importing #{relative}: #{e.message}")
        end
      end

      log.call("Incremental seed complete: #{imported} imported, #{skipped} unchanged")

      {imported: imported, skipped: skipped}
    end

    def self.changes
      signature = state_signature
      cached = @changes_cache
      return cached[:changes] if cached && cached[:signature] == signature

      result = compute_changes
      @changes_cache = {signature: signature, changes: result}
      result
    end

    def self.data_files
      seed_phases.flatten.map { |path| ImportedFile.relative_path(path) }.uniq
    end

    def self.compute_changes
      stored = ImportedFile.pluck(:file_path, :fingerprint).to_h
      on_disk = data_files

      pending = on_disk.filter_map do |relative|
        digest = ImportedFile.digest(relative)
        next if stored[relative] == digest

        {path: relative, status: stored.key?(relative) ? "modified" : "new"}
      end

      deleted = (stored.keys - on_disk).map { |relative| {path: relative, status: "deleted"} }

      (pending + deleted).sort_by { |change| change[:path] }
    end

    def self.state_signature
      paths = seed_phases.flatten
      latest_mtime = paths.filter_map { |path| File.mtime(path).to_i if File.exist?(path) }.max

      [paths.size, latest_mtime, ImportedFile.count, ImportedFile.maximum(:updated_at)&.to_i]
    end

    def self.with_event(event_slug)
      static = Static::Event.find_by_slug(event_slug)
      return false unless static

      record = ::Event.find_by(slug: event_slug) || static.import_event!
      return false unless record

      yield(static, record)

      true
    end

    def self.seed_phases
      phases.map { |models| models.flat_map { |model| files_for(model) } }
    end

    def self.files_for(model)
      model.file_glob ? Dir[model.file_glob].sort : [model.file_path]
    end

    # Schedules are matched (so their files count as handled) but not part of the seed phases.
    def self.model_for(absolute_path)
      (phases.flatten + [Static::Schedule]).find do |model|
        if model.file_glob
          File.fnmatch?(model.file_glob, absolute_path, File::FNM_PATHNAME)
        else
          model.file_path == absolute_path
        end
      end
    end

    # Event records cache their per-event files, so those need the events reloaded too.
    def self.reload_caches_for(model)
      model.unload!
      Static::Event.unload! unless model.in?(GLOBAL_MODELS) || model == Static::EventSeries
    end
  end
end
