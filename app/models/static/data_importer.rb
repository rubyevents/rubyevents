# frozen_string_literal: true

module Static
  class DataImporter
    SPEAKERS = "data/speakers.yml"
    TOPICS = "data/topics.yml"
    FEATURED_CITIES = "data/featured_cities.yml"

    class << self
      def import(path, reload: false)
        relative = ImportedFile.relative_path(path)

        reload_caches_for(relative) if reload

        case relative
        when SPEAKERS
          Static::Speaker.import_all!

          true
        when TOPICS
          Static::Topic.import_all!

          true
        when FEATURED_CITIES
          Static::City.import_all!

          true
        when %r{\Adata/([^/]+)/series\.yml\z}
          series = Static::EventSeries.find_by_slug($1)

          if series
            series.import_series!
            true
          else
            false
          end
        when %r{\Adata/([^/]+)/([^/]+)/(?:event|venue)\.yml\z}
          event = Static::Event.find_by_slug($2)

          if event
            event.import_event!
            true
          else
            false
          end
        when %r{\Adata/([^/]+)/([^/]+)/videos\.yml\z}
          with_event($2) { |static, record| static.import_videos!(record) }
        when %r{\Adata/([^/]+)/([^/]+)/sponsors\.yml\z}
          with_event($2) { |static, record| static.import_sponsors!(record) }
        when %r{\Adata/([^/]+)/([^/]+)/cfp\.yml\z}
          with_event($2) { |static, record| static.import_cfps!(record) }
        when %r{\Adata/([^/]+)/([^/]+)/involvements\.yml\z}
          with_event($2) { |static, record| static.import_involvements!(record) }
        when %r{\Adata/([^/]+)/([^/]+)/schedule\.yml\z}
          true
        else
          false
        end
      end

      def seed_changed!(reload: false, force: false, logger: nil)
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

      def changes
        signature = state_signature
        cached = @changes_cache
        return cached[:changes] if cached && cached[:signature] == signature

        result = compute_changes
        @changes_cache = {signature: signature, changes: result}
        result
      end

      def data_files
        seed_phases.flatten.map { |path| ImportedFile.relative_path(path) }.uniq
      end

      private

      def compute_changes
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

      def state_signature
        paths = seed_phases.flatten
        latest_mtime = paths.filter_map { |path| File.mtime(path).to_i if File.exist?(path) }.max

        [paths.size, latest_mtime, ImportedFile.count, ImportedFile.maximum(:updated_at)&.to_i]
      end

      def with_event(event_slug)
        static = Static::Event.find_by_slug(event_slug)
        return false unless static

        record = ::Event.find_by(slug: event_slug) || static.import_event!
        return false unless record

        yield(static, record)

        true
      end

      def seed_phases
        [
          [data_glob("featured_cities.yml")],
          [data_glob("speakers.yml")],
          Dir[data_glob("*/series.yml")],
          Dir[data_glob("*/*/event.yml")],
          Dir[data_glob("*/*/venue.yml")],
          Dir[data_glob("*/*/{videos,sponsors,cfp,involvements}.yml")],
          [data_glob("topics.yml")]
        ]
      end

      def data_glob(pattern)
        Rails.root.join("data", pattern).to_s
      end

      def reload_caches_for(relative)
        case relative
        when SPEAKERS
          reload(Static::Speaker)
        when TOPICS
          reload(Static::Topic)
        when FEATURED_CITIES
          reload(Static::City)
        when %r{\Adata/[^/]+/series\.yml\z}
          reload(Static::EventSeries)
        else
          reload(Static::Event)
          reload(Static::Video)
        end
      end

      def reload(model)
        model.unload! if model.respond_to?(:unload!)
        model.instance_variable_set(:@slug_index, nil) if model.instance_variable_defined?(:@slug_index)
      end
    end
  end
end
