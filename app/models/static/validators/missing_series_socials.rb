# frozen_string_literal: true

module Static
  module Validators
    class MissingSeriesSocials
      PATTERNS = [
        "**/event.yml"
      ].freeze

      ACCOUNT_FIELDS = %w[facebook instagram mastodon twitter].freeze

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
        missing_fields.map do |field|
          location = document[field]&.location

          Static::Validators::Error.new(
            %(#{field} (#{document.value_at(field)}) is not defined in series.yml — move it to series.yml so every event in the series shares it. Run `bin/rails validate:fix` to move it.),
            file_path: @file_path,
            line: location&.start_line || 1,
            end_line: location&.end_line
          )
        end
      end

      def fix
        return unless applicable?

        fields = missing_fields.reject { |field| conflicting_sibling?(field) }
        return if fields.empty?

        fields.each do |field|
          series_document[field] = document.value_at(field)
          document.delete(field)
        end

        series_document.save!(apply: true)
        document.save!(apply: true)

        {changed: fields.size, file_path: @file_path}
      end

      private

      def document
        @document ||= Yerba.parse_file(@file_path.to_s)
      end

      def series_directory
        File.dirname(@file_path.to_s, 2)
      end

      def series_document
        return @series_document if defined?(@series_document)

        series_path = File.join(series_directory, "series.yml")
        @series_document = File.exist?(series_path) ? Yerba.parse_file(series_path) : nil
      end

      def missing_fields
        return [] unless applicable?
        return [] unless series_document

        event_values = document.values || {}
        series_values = series_document.values || {}

        ACCOUNT_FIELDS.select do |field|
          event_values[field].to_s.strip.present? && series_values[field].to_s.strip.blank?
        end
      end

      def conflicting_sibling?(field)
        value = normalize(document.value_at(field))

        sibling_paths.any? do |path|
          sibling_value = normalize((Yerba.parse_file(path).values || {})[field])
          sibling_value.present? && sibling_value != value
        end
      end

      def sibling_paths
        Dir.glob(File.join(series_directory, "*", "event.yml")) - [@file_path.to_s]
      end

      def normalize(value)
        value.to_s.strip.downcase.delete_prefix("@").delete_suffix("/")
      end
    end
  end
end
