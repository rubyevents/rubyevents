# frozen_string_literal: true

module Static
  module Validators
    class EventRecordingsPublishedDate
      WATCHABLE_PROVIDERS = %w[youtube mp4 vimeo].freeze
      TERMINAL_PROVIDERS = %w[not_recorded not_published].freeze
      PERCENTILE = 90

      def self.percentile(dates, percentile = PERCENTILE)
        return nil if dates.empty?

        sorted = dates.sort
        rank = (percentile / 100.0 * sorted.size).ceil

        sorted[[rank - 1, 0].max]
      end

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

        future_start_errors = validate_absence_for_future_start
        return future_start_errors if future_start_errors.any?

        videos_path = File.join(File.dirname(@file_path), "videos.yml")

        return [] unless File.exist?(videos_path)

        @videos = Yerba.parse_file(videos_path).to_a

        return [] unless @videos.is_a?(Array) && @videos.any?

        errors = []

        if @event_document["recordings_published_date"].present?
          if majority_published?
            errors.concat(validate_not_before_event_dates)
            errors.concat(validate_not_before_video_published_dates)
          else
            errors.concat(validate_absence)
          end
        elsif majority_published?
          errors.concat(validate_presence)
        end

        errors
      end

      private

      def meetup?
        @event_document["kind"]&.value == "meetup"
      end

      def majority_published?
        resolvable_count.positive? && watchable_count * 2 > resolvable_count
      end

      def watchable_count
        @videos.count { |video| video["video_provider"]&.in?(WATCHABLE_PROVIDERS) }
      end

      def resolvable_count
        @videos.count { |video| !video["video_provider"]&.in?(TERMINAL_PROVIDERS) }
      end

      def validate_absence_for_meetup
        return [] if @event_document["recordings_published_date"].blank?

        location = @event_document["recordings_published_date"]&.location

        [
          Static::Validators::Error.new(
            "recordings_published_date (#{@event_document["recordings_published_date"]}) must not be set for meetups",
            file_path: @file_path,
            line: location&.start_line || 1,
            end_line: location&.end_line
          )
        ]
      end

      def validate_absence_for_future_start
        return [] if @event_document["recordings_published_date"].blank?

        start_date = parse_date(@event_document["start_date"])

        return [] unless start_date && start_date > Date.current

        location = @event_document["recordings_published_date"]&.location

        [
          Static::Validators::Error.new(
            "recordings_published_date (#{@event_document["recordings_published_date"]}) must not be set for an event that has not started yet (start_date #{@event_document["start_date"]} is in the future)",
            file_path: @file_path,
            line: location&.start_line || 1,
            end_line: location&.end_line
          )
        ]
      end

      def validate_presence
        [
          Static::Validators::Error.new(
            "recordings_published_date is required when the majority of talks are published (#{watchable_count}/#{resolvable_count} resolvable talks published)",
            file_path: @file_path,
            line: 1
          )
        ]
      end

      def validate_absence
        location = @event_document["recordings_published_date"]&.location

        [
          Static::Validators::Error.new(
            "recordings_published_date (#{@event_document["recordings_published_date"]}) must not be set unless the majority of talks are published (#{watchable_count}/#{resolvable_count} resolvable talks published)",
            file_path: @file_path,
            line: location&.start_line || 1,
            end_line: location&.end_line
          )
        ]
      end

      def validate_not_before_event_dates
        published_date = parse_date(@event_document["recordings_published_date"])

        return [] unless published_date

        errors = []
        start_date = parse_date(@event_document["start_date"])

        if start_date && published_date < start_date
          location = @event_document["recordings_published_date"]&.location

          errors << Static::Validators::Error.new(
            "recordings_published_date (#{@event_document["recordings_published_date"]}) must not be before start_date (#{@event_document["start_date"]})",
            file_path: @file_path,
            line: location&.start_line || 1,
            end_line: location&.end_line
          )
        end

        end_date = parse_date(@event_document["end_date"])

        if end_date && published_date < end_date
          location = @event_document["recordings_published_date"]&.location

          errors << Static::Validators::Error.new(
            "recordings_published_date (#{@event_document["recordings_published_date"]}) must not be before end_date (#{@event_document["end_date"]})",
            file_path: @file_path,
            line: location&.start_line || 1,
            end_line: location&.end_line
          )
        end

        errors
      end

      def validate_not_before_video_published_dates
        published_date = parse_date(@event_document["recordings_published_date"])

        return [] unless published_date

        video_dates = @videos.filter_map { |video| parse_date(video["published_at"]) }
        reference_date = self.class.percentile(video_dates)

        return [] unless reference_date

        if published_date < reference_date
          location = @event_document["recordings_published_date"]&.location

          [
            Static::Validators::Error.new(
              "recordings_published_date (#{@event_document["recordings_published_date"]}) must not be before the P#{PERCENTILE} of the video published_at dates (#{reference_date})",
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
