# frozen_string_literal: true

module Static
  module Validators
    class SeriesDefaultColors
      PATTERNS = ["**/series.yml"].freeze

      FIELD_ASSET_MAP = {
        "banner_background" => "banner.webp",
        "featured_background" => "featured.webp",
        "featured_color" => "featured.webp"
      }.freeze

      def initialize(file_path:, document: nil)
        @file_path = file_path
        @document = document
      end

      def applicable?
        return false unless File.exist?(@file_path)

        PATTERNS.any? do |pattern|
          File.fnmatch?(pattern, @file_path, File::FNM_PATHNAME | File::FNM_DOTMATCH)
        end
      end

      def errors
        @errors ||= validate
      end

      def validate
        return [] unless applicable?

        match = File.expand_path(@file_path).match(%r{\A(?<root>.*)/data/(?<series>[^/]+)/series\.yml\z})
        return [] unless match

        root = Pathname.new(match[:root])
        default_asset_dir = root.join("app", "assets", "images", "events", match[:series], "default")

        FIELD_ASSET_MAP.filter_map do |field, asset|
          asset_path = default_asset_dir.join(asset).relative_path_from(root)
          asset_exists = File.exist?(default_asset_dir.join(asset))
          defined = document[field].present?

          if asset_exists && !defined
            Static::Validators::Error.new(
              "#{field} is not defined but '#{asset_path}' exists, series with a default #{asset} must define its brand colors",
              file_path: @file_path,
              line: 1
            )
          elsif defined && !asset_exists
            location = document[field].location

            Static::Validators::Error.new(
              "#{field} is defined but '#{asset_path}' does not exist, series without a default #{asset} must not define brand colors",
              file_path: @file_path,
              line: location&.start_line || 1,
              end_line: location&.end_line
            )
          end
        end
      end

      private

      def document
        @document ||= Yerba.parse_file(@file_path.to_s)
      end
    end
  end
end
