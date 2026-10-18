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
          location = document[field]&.location

          Static::Validators::Error.new(
            %(#{field} (#{document.value_at(field)}) is already defined in series.yml — remove it from event.yml and keep it on series.yml. Run `bin/rails validate:fix` to remove it.),
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

        fields.each { |field| document.delete(field) }
        document.save!(apply: true)

        {changed: fields.size, file_path: @file_path}
      end

      private

      def document
        @document ||= Yerba.parse_file(@file_path.to_s)
      end

      def series_document
        return @series_document if defined?(@series_document)

        series_path = File.join(File.dirname(@file_path.to_s, 2), "series.yml")
        @series_document = File.exist?(series_path) ? Yerba.parse_file(series_path) : nil
      end

      def duplicate_fields
        return [] unless applicable?
        return [] unless series_document

        event_values = document.values || {}
        series_values = series_document.values || {}

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
