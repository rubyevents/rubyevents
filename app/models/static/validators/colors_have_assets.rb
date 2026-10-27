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
          File.fnmatch?(pattern, @file_path, File::FNM_PATHNAME | File::FNM_DOTMATCH)
        end
      end

      def errors
        @errors ||= validate
      end

      def validate
        return [] unless applicable?

        match = File.expand_path(@file_path).match(%r{\A(?<root>.*?)/data/(?:[^/]+/)*(?<series>[^/]+)/(?<event>[^/]+)/event\.yml\z})
        return [] unless match

        root = Pathname.new(match[:root])
        assets_base = root.join("app", "assets", "images", "events", match[:series])
        asset_dir = assets_base.join(match[:event])
        default_asset_dir = assets_base.join("default")

        FIELD_ASSET_MAP
          .map do |field, asset|
            next unless event[field].present?
            next if File.exist?(asset_dir.join(asset))

            location = event.source_location(field)

            message = if File.exist?(default_asset_dir.join(asset))
              "#{field} is defined but #{asset} comes from the series default '#{default_asset_dir.join(asset).relative_path_from(root)}', define #{field} in data/#{match[:series]}/series.yml instead"
            else
              "#{field} is defined but '#{asset}' exists neither in #{asset_dir.relative_path_from(root)} nor in #{default_asset_dir.relative_path_from(root)}, events falling back to the global default #{asset} must not define brand colors"
            end

            Static::Validators::Error.new(
              message,
              file_path: @file_path,
              location: location
            )
          end.compact
      end

      private

      def event
        @event ||= Static::Event.in_file(@file_path.to_s, document: @document).first
      end
    end
  end
end
