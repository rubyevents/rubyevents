# frozen_string_literal: true

module Static
  module Validators
    class DuplicateSeriesSocials
      PATTERNS = [
        "**/event.yml"
      ].freeze

      SOCIAL_FIELDS = %w[facebook github instagram luma mastodon meetup twitter].freeze

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
        duplicate_fields.map do |field|
          location = event.source_location(field)

          Static::Validators::Error.new(
            %(#{field} (#{event[field]}) is already defined in series.yml — remove it from event.yml and keep it on series.yml. Run `bin/rails validate:fix` to remove it.),
            file_path: @file_path,
            line: location&.start_line || 1,
            end_line: location&.end_line
          )
        end
      end

      def fix
        return unless applicable?

        fields = duplicate_fields
        return if fields.empty?

        fields.each { |field| event.delete(field) }
        event.save!

        {changed: fields.size, file_path: @file_path}
      end

      private

      def event
        @event ||= Static::Event.in_file(@file_path.to_s, document: @document).first
      end

      def series
        return @series if defined?(@series)

        series_path = File.join(File.dirname(@file_path.to_s, 2), "series.yml")
        @series = File.exist?(series_path) ? Static::EventSeries.in_file(series_path).first : nil
      end

      def duplicate_fields
        return [] unless applicable?
        return [] unless series

        event_values = event.to_h
        series_values = series.to_h

        SOCIAL_FIELDS.select do |field|
          event_value = normalize(event_values[field])
          event_value.present? && event_value == normalize(series_values[field])
        end
      end

      def normalize(value)
        value.to_s.strip.downcase.delete_prefix("@").delete_suffix("/")
      end
    end
  end
end
