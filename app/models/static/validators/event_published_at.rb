# frozen_string_literal: true

module Static
  module Validators
    class EventPublishedAt
      WATCHABLE_PROVIDERS = %w[youtube mp4 vimeo].freeze

      def initialize(file_path:)
        @file_path = file_path
      end

      PATTERNS = [
        "**/event.yml"
      ].freeze

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

        @event_document = Yerba.parse_file(@file_path)

        return validate_absence_for_meetup if meetup?

        videos_path = File.join(File.dirname(@file_path), "videos.yml")

        return [] unless File.exist?(videos_path)

        @videos = YAML.load_file(videos_path)

        return [] unless @videos.is_a?(Array) && @videos.any?

        errors = []

        if @event_document["published_at"].present?
          errors.concat(validate_not_before_event_dates)
          errors.concat(validate_not_before_video_published_dates)
        else
          errors.concat(validate_presence)
        end

        errors
      end

      private

      def meetup?
        @event_document["kind"]&.value == "meetup"
      end

      def validate_absence_for_meetup
        return [] if @event_document["published_at"].blank?

        location = @event_document["published_at"]&.location

        [
          Static::Validators::Error.new(
            "published_at (#{@event_document["published_at"]}) must not be set for meetups",
            file_path: @file_path,
            line: location&.start_line || 1,
            end_line: location&.end_line
          )
        ]
      end

      def validate_presence
        watchable_count = @videos.count { |video| video["video_provider"]&.in?(WATCHABLE_PROVIDERS) }

        return [] if watchable_count == 0

        [
          Static::Validators::Error.new(
            "published_at is required when event has watchable talks (#{watchable_count} watchable talks found)",
            file_path: @file_path,
            line: 1
          )
        ]
      end

      def validate_not_before_event_dates
        published_at = parse_date(@event_document["published_at"])

        return [] unless published_at

        errors = []
        start_date = parse_date(@event_document["start_date"])

        if start_date && published_at < start_date
          location = @event_document["published_at"]&.location

          errors << Static::Validators::Error.new(
            "published_at (#{@event_document["published_at"]}) must not be before start_date (#{@event_document["start_date"]})",
            file_path: @file_path,
            line: location&.start_line || 1,
            end_line: location&.end_line
          )
        end

        end_date = parse_date(@event_document["end_date"])

        if end_date && published_at < end_date
          location = @event_document["published_at"]&.location

          errors << Static::Validators::Error.new(
            "published_at (#{@event_document["published_at"]}) must not be before end_date (#{@event_document["end_date"]})",
            file_path: @file_path,
            line: location&.start_line || 1,
            end_line: location&.end_line
          )
        end

        errors
      end

      def validate_not_before_video_published_dates
        published_at = parse_date(@event_document["published_at"])

        return [] unless published_at

        latest_video = @videos.filter_map { |video| parse_date(video["published_at"]) }.max

        return [] unless latest_video

        if published_at < latest_video
          location = @event_document["published_at"]&.location
          [
            Static::Validators::Error.new(
              "published_at (#{@event_document["published_at"]}) must not be before the latest video published_at (#{latest_video})",
              file_path: @file_path,
              line: location&.start_line || 1,
              end_line: location&.end_line
            )
          ]
        else
          []
        end
      end

      def parse_date(value)
        Date.parse(value.to_s)
      rescue Date::Error, TypeError
        nil
      end
    end
  end
end
