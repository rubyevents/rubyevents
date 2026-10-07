# frozen_string_literal: true

module Static
  module Validators
    class SeriesDefaultColors
      PATTERNS = ["**/event.yml"].freeze

      FIELD_ASSET_MAP = {
        "banner_background" => "banner.webp",
        "featured_background" => "featured.webp",
        "featured_color" => "featured.webp"
      }.freeze

      def initialize(file_path:, document: nil)
        @file_path = file_path.to_s.sub("#{Rails.root}/", "")
      end

      def applicable?
        return false unless File.exist?(@file_path)

        PATTERNS.any? do |pattern|
          File.fnmatch?(pattern, @file_path, File::FNM_PATHNAME)
        end
      end

      def errors
        return [] unless applicable?

        self.class.errors.select { |error| error.file_path == @file_path }
      end

      def self.errors
        @errors ||= mismatch_errors(
          data_root: Rails.root.join("data").to_s,
          assets_root: Rails.root.join("app", "assets", "images", "events").to_s
        )
      end

      def self.warmup
        errors
      end

      def self.reset!
        @errors = nil
      end

      def self.mismatch_errors(data_root:, assets_root:)
        Dir.glob(File.join(assets_root, "*", "default")).sort.flat_map do |default_dir|
          series_errors(
            series_slug: File.basename(File.dirname(default_dir)),
            data_root: data_root,
            assets_root: assets_root
          )
        end
      end

      def self.series_errors(series_slug:, data_root:, assets_root:)
        references = Hash.new { |hash, key| hash[key] = [] }

        Dir.glob(File.join(data_root, series_slug, "*", "event.yml")).sort.each do |file|
          event_slug = File.basename(File.dirname(file))
          document = Yerba.parse_file(file)

          FIELD_ASSET_MAP.each do |field, asset|
            next if File.exist?(File.join(assets_root, series_slug, event_slug, asset))
            next unless File.exist?(File.join(assets_root, series_slug, "default", asset))

            scalar = document[field]
            next unless scalar

            references[field] << {
              value: scalar.value,
              asset: Pathname.new(assets_root).join(series_slug, "default", asset).relative_path_from(Rails.root).to_s,
              file: file,
              line: scalar.location&.start_line || 1,
              end_line: scalar.location&.end_line
            }
          end
        end

        references.flat_map do |field, refs|
          tally = refs.map { |reference| reference[:value] }.tally
          next [] unless tally.many?

          expected, count = tally.max_by { |_value, occurrences| occurrences }

          refs.reject { |reference| reference[:value] == expected }.map do |reference|
            Static::Validators::Error.new(
              %(#{field} "#{reference[:value]}" does not match "#{expected}" used by #{count} other #{series_slug} events falling back to the series default #{reference[:asset]}),
              file_path: reference[:file],
              line: reference[:line],
              end_line: reference[:end_line]
            )
          end
        end
      end
    end
  end
end
