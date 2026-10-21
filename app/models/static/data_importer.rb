# frozen_string_literal: true

module Static
  class DataImporter
    FULL_REINDEX_THRESHOLD = 10
    GLOBAL_MODELS = [Static::City, Static::Speaker, Static::Topic].freeze

    EVENT_FILE_IMPORTS = {
      Static::Talk => :import_videos!,
      Static::Sponsor => :import_sponsors!,
      Static::CFP => :import_cfps!,
      Static::Involvement => :import_involvements!
    }.freeze

    EVENT_FILE_ASSOCIATIONS = {
      Static::Sponsor => :sponsors,
      Static::CFP => :cfps,
      Static::Involvement => :event_involvements
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

        record = event.import_event!
        event.destroy_removed_talks!(record)

        true
      elsif model == Static::Schedule
        true
      else
        with_event(folder) { |static, record| static.public_send(EVENT_FILE_IMPORTS.fetch(model), record) }
      end
    end

    def self.remove(path, reload: true)
      absolute = Rails.root.join(ImportedFile.relative_path(path)).to_s
      model = model_for(absolute)
      return false unless model

      reload_caches_for(model) if reload

      folder = File.basename(File.dirname(absolute))

      if (association = EVENT_FILE_ASSOCIATIONS[model])
        event = ::Event.find_by(slug: folder)
        return false unless event

        event.public_send(association).destroy_all
        true
      elsif model == Static::Venue
        event = Static::Event.find_by_slug(folder)
        return false unless event

        event.import_event!
        true
      else
        false
      end
    end

    def self.sync(paths, logger: nil)
      log = logger || method(:puts)
      relatives = paths.map { |path| ImportedFile.relative_path(path) }.uniq

      unload_all!

      with_indexing_for(relatives.size) { seed_changed!(only: relatives, logger: log) }
    end

    def self.with_indexing_for(pending_count, force: false)
      started_at = Time.current

      if force || pending_count > FULL_REINDEX_THRESHOLD
        result = Search::Backend.without_indexing { yield }
        Search::Backend.reindex_all if changed?(result)
      else
        result = yield
        Search::Backend.reindex_changed_since(started_at) if changed?(result)
      end

      result
    end

    def self.changed?(result)
      (result[:imported] + result[:removed]).positive?
    end

    def self.unload_all!
      (phases.flatten + [Static::Schedule]).each(&:unload!)
    end

    def self.seed_changed!(only: nil, force: false, logger: nil)
      log = logger || method(:puts)
      only = only&.to_set
      imported = 0
      removed = 0
      skipped = 0
      failed = []

      ImportedFile.missing_paths.each do |relative|
        next if only && !only.include?(relative)

        removed += 1 if remove(relative, reload: false)
        ImportedFile.forget!(relative)
        log.call("removed #{relative}")
      rescue => e
        failed << relative
        log.call("error removing #{relative}: #{e.class}: #{e.message}")
      end

      seed_phases.each do |paths|
        paths.each do |path|
          relative = ImportedFile.relative_path(path)
          next if only && !only.include?(relative)

          unless force || ImportedFile.changed?(relative)
            skipped += 1
            next
          end

          if import(relative)
            ImportedFile.record!(relative)
            imported += 1
            log.call("imported #{relative}")
          else
            failed << relative
            log.call("error importing #{relative}: no matching event or series in data/")
          end
        rescue => e
          failed << relative
          log.call("error importing #{relative}: #{e.class}: #{e.message}")
        end
      end

      log.call("Incremental seed complete: #{imported} imported, #{removed} removed, #{skipped} unchanged, #{failed.size} failed")

      {imported: imported, removed: removed, skipped: skipped, failed: failed}
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

    def self.model_for(absolute_path)
      (phases.flatten + [Static::Schedule]).find do |model|
        if model.file_glob
          File.fnmatch?(model.file_glob, absolute_path, File::FNM_PATHNAME)
        else
          model.file_path == absolute_path
        end
      end
    end

    def self.reload_caches_for(model)
      model.unload!

      Static::Event.unload! unless model.in?(GLOBAL_MODELS) || model == Static::EventSeries
    end
  end
end
