# frozen_string_literal: true

module Static
  module Validators
    class ColorsHaveAssets
      PATTERNS = ["**/event.yml"].freeze

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
          File.fnmatch?(pattern, @file_path, File::FNM_PATHNAME)
        end
      end

      def errors
        @errors ||= validate
      end

      def validate
        return [] unless applicable?

        path_parts = @file_path.split("/")
        series_slug = path_parts[-3]
        event_slug = path_parts[-2]

        assets_base = Rails.root.join("app", "assets", "images", "events")
        asset_dir = assets_base.join(series_slug, event_slug)
        default_asset_dir = assets_base.join(series_slug, "default")

        FIELD_ASSET_MAP
          .map do |field, asset|
            next unless document[field].present?
            next if File.exist?(asset_dir.join(asset)) || File.exist?(default_asset_dir.join(asset))
            location = document[field].location

            Static::Validators::Error.new(
              "Color field configured but asset '#{asset}' not found in #{asset_dir} or #{default_asset_dir}",
              file_path: @file_path,
              line: location&.start_line || 1,
              end_line: location&.end_line
            )
          end.compact
      end

      private

      def document
        @document ||= Yerba.parse_file(@file_path.to_s)
      end
    end
  end
end
