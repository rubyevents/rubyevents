# frozen_string_literal: true

module Static
  class DataImporter
    FULL_REINDEX_THRESHOLD = 10
    def self.global_models
      [Static::City, Static::Speaker, Static::Topic]
    end

    def self.event_file_imports
      {
        Static::Talk => :import_videos!,
        Static::Sponsor => :import_sponsors!,
        Static::CFP => :import_cfps!,
        Static::Involvement => :import_involvements!
      }
    end

    def self.event_file_associations
      {
        Static::Sponsor => :sponsors,
        Static::CFP => :cfps,
        Static::Involvement => :event_involvements
      }
    end

    def self.series_file_imports
      {
        Static::SeriesCFP => :import_cfps!,
        Static::SeriesSponsor => :import_sponsors!,
        Static::SeriesInvolvement => :import_involvements!
      }
    end

    def self.series_file_associations
      {
        Static::SeriesSponsor => :sponsors,
        Static::SeriesCFP => :cfps,
        Static::SeriesInvolvement => :event_involvements
      }
    end

    def self.series_models
      [Static::EventSeries, *series_file_imports.keys]
    end

    def self.phases
      [
        [Static::City],
        [Static::Speaker],
        [Static::EventSeries],
        [Static::Event],
        [Static::Venue],
        event_file_imports.keys,
        series_file_imports.keys,
        [Static::Topic]
      ]
    end

    def self.import(path, reload: false)
      absolute = Rails.root.join(ImportedFile.relative_path(path)).to_s
      model = model_for(absolute)
      return false unless model

      reload_caches_for(model) if reload

      if model.in?(global_models)
        model.import_all!

        true
      elsif model == Static::EventSeries
        series = series_for(absolute)
        return false unless series

        series.import_series!
        true
      elsif (method = series_file_imports[model])
        series = series_for(absolute)
        return false unless series

        series.public_send(method, series.event_series_record)
        true
      elsif model.in?([Static::Event, Static::Venue])
        event = event_for(absolute)
        return false unless event

        record = event.import_event!
        event.destroy_removed_talks!(record)

        true
      elsif model == Static::Schedule
        true
      else
        with_event(event_for(absolute)) { |static, record| static.public_send(event_file_imports.fetch(model), record) }
      end
    end

    def self.remove(path, reload: true)
      absolute = Rails.root.join(ImportedFile.relative_path(path)).to_s
      model = model_for(absolute)
      return false unless model

      reload_caches_for(model) if reload

      if (association = event_file_associations[model])
        static = event_for(absolute)
        event = static && ::Event.find_by(slug: static.slug)
        return false unless event

        event.public_send(association).destroy_all
        true
      elsif (association = series_file_associations[model])
        static = series_for(absolute)
        event_series = static && ::EventSeries.find_by(slug: static.slug)
        return false unless event_series

        event_series.public_send(association).destroy_all
        true
      elsif model == Static::Venue
        event = event_for(absolute)
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
      touched = []

      ImportedFile.missing_paths.each do |relative|
        next if only && !only.include?(relative)

        removed += 1 if remove(relative, reload: false)
        ImportedFile.forget!(relative)
        touched << relative
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
            touched << relative
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

      failed.concat(finalize!(touched, logger: log))

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

    def self.finalize!(relatives, logger:)
      absolutes = relatives.map { |relative| Rails.root.join(relative).to_s }
      models = absolutes.index_with { |absolute| model_for(absolute) }

      events = models.filter_map { |absolute, model| event_for(absolute) if model && !model.in?(global_models) && !model.in?(series_models) }.uniq
      series = (models.filter_map { |absolute, model| series_for(absolute) if model&.in?(series_models) } + events.filter_map(&:series)).uniq

      failed = []

      migrating = events.select { |event| event.old_talk_ids.any? }
      records = ::Event.where(slug: migrating.map(&:slug)).index_by(&:slug)

      migrating.each do |event|
        record = records[event.slug]
        event.migrate_old_talks!(record) if record
      rescue => e
        failed << forget_after_failure(event.file_path, e, logger)
      end

      series.each do |static_series|
        record = static_series.event_series_record

        static_series.merge_old_events!(record)
        static_series.update_frequency!(record)
      rescue => e
        failed << forget_after_failure(static_series.file_path, e, logger)
      end

      failed
    end

    def self.forget_after_failure(file_path, error, logger)
      relative = ImportedFile.relative_path(file_path)

      ImportedFile.forget!(relative)
      logger.call("error finishing #{relative}: #{error.class}: #{error.message}")

      relative
    end

    def self.event_for(absolute_path)
      Static::Event.find_by_file_path(File.join(File.dirname(absolute_path), "event.yml"))
    end

    def self.series_for(absolute_path)
      Static::EventSeries.find_by_file_path(File.join(File.dirname(absolute_path), "series.yml"))
    end

    def self.with_event(static)
      return false unless static

      record = ::Event.find_by(slug: static.slug) || static.import_event!
      return false unless record

      yield(static, record)

      true
    end

    def self.seed_phases
      phases.map { |models| models.flat_map { |model| files_for(model) } }
    end

    def self.files_for(model)
      return [model.file_path] unless model.file_glob

      Dir[model.file_glob].sort.select { |file| model.sibling_file?(file) }
    end

    def self.model_for(absolute_path)
      (phases.flatten + [Static::Schedule]).find do |model|
        if model.file_glob
          model.path_params_for(absolute_path) && model.sibling_file?(absolute_path)
        else
          model.file_path == absolute_path
        end
      end
    end

    def self.reload_caches_for(model)
      model.unload!

      return if model.in?(global_models)

      Static::Event.unload!
      Static::EventSeries.unload!
    end
  end
end
