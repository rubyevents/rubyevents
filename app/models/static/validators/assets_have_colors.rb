# frozen_string_literal: true

module Static
  module Validators
    class AssetsHaveColors
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
          File.fnmatch?(pattern, @file_path, File::FNM_PATHNAME | File::FNM_DOTMATCH)
        end
      end

      def errors
        @errors ||= validate
      end

      def validate
        return [] unless applicable?

        match = File.expand_path(@file_path).match(%r{\A(?<root>.*)/data/(?<series>[^/]+)/(?<event>[^/]+)/event\.yml\z})
        return [] unless match

        asset_dir = Pathname.new(match[:root]).join("app", "assets", "images", "events", match[:series], match[:event])

        FIELD_ASSET_MAP
          .map do |field, asset|
            next if document[field].present?
            next unless File.exist?(asset_dir.join(asset))

            Static::Validators::Error.new(
              "#{field} is not defined but '#{asset_dir.join(asset).relative_path_from(match[:root])}' exists, events with a custom #{asset} must define brand colors",
              file_path: @file_path,
              line: 1
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
