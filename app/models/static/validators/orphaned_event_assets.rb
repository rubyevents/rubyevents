# frozen_string_literal: true

module Static
  module Validators
    class OrphanedEventAssets
      PATTERNS = ["**/*.webp"].freeze

      ASSETS_BASE = "app/assets/images/events"

      def initialize(file_path:, document: nil)
        @file_path = file_path.to_s
      end

      def applicable?
        return false unless File.exist?(@file_path)
        return false unless @file_path.include?("#{ASSETS_BASE}/")

        PATTERNS.any? do |pattern|
          File.fnmatch?(pattern, @file_path, File::FNM_PATHNAME)
        end
      end

      def errors
        @errors ||= validate
      end

      def validate
        return [] unless applicable?

        segments = @file_path.split("#{ASSETS_BASE}/").last.split("/")[0..-2]
        return [] if segments == ["default"]

        series_slug, event_slug = segments

        return [] if event_slug.nil? && Static::Validators::OrphanedEventAssets.series_exists?(series_slug)

        if event_slug.present? && Static::Validators::OrphanedEventAssets.series_exists?(series_slug)
          return [] if event_slug == "default"
          return [] if Static::Validators::OrphanedEventAssets.event_exists?(series_slug, event_slug)
        end

        [
          Static::Validators::Error.new(
            "Asset does not belong to any event, there is no matching folder in data/#{segments.join("/")}",
            file_path: @file_path,
            line: 1
          )
        ]
      end

      def self.series_exists?(series_slug)
        File.exist?(Rails.root.join("data", series_slug.to_s, "series.yml"))
      end

      def self.event_exists?(series_slug, event_slug)
        File.exist?(Rails.root.join("data", series_slug.to_s, event_slug.to_s, "event.yml"))
      end
    end
  end
end
