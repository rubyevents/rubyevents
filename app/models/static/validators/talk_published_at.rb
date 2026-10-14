# frozen_string_literal: true

module Static
  module Validators
    class TalkPublishedAt
      PATTERNS = [
        "**/videos.yml"
      ].freeze

      PROVIDERS_WITHOUT_PUBLISHED_AT = (::Talk::UNPUBLISHED_PROVIDERS + ["children", "parent"]).freeze

      def initialize(file_path:, document: nil)
        @file_path = file_path.to_s.sub("#{Rails.root}/", "")
      end

      def applicable?
        return false unless File.exist?(@file_path)

        PATTERNS.any? do |pattern|
          File.fnmatch?(pattern, @file_path, File::FNM_PATHNAME | File::FNM_DOTMATCH)
        end
      end

      def errors
        return [] unless applicable?

        self.class.errors.select { |error| error.file_path == @file_path }
      end

      def self.errors
        talks = Static::Talk.all
        return @errors if @talks.equal?(talks)

        @talks = talks
        @errors = talks.where(video_provider: PROVIDERS_WITHOUT_PUBLISHED_AT).where.not(published_at: [nil, ""]).map do |talk|
          location = talk.source_location("published_at")

          Static::Validators::Error.new(
            "published_at (#{talk["published_at"]}) must not be set when video_provider is \"#{talk["video_provider"]}\"",
            file_path: talk.file_path.to_s,
            line: location&.start_line || 1,
            end_line: location&.end_line
          )
        end
      end

      def self.warmup
        errors
      end
    end
  end
end
