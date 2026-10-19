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
          location = event.source_location(field)

          Static::Validators::Error.new(
            %(#{field} (#{event[field]}) is not defined in series.yml — move it to series.yml so every event in the series shares it. Run `bin/rails validate:fix` to move it.),
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
          series[field] = event[field]
          event.delete(field)
        end

        series.save!
        event.save!

        {changed: fields.size, file_path: @file_path}
      end

      private

      def event
        @event ||= Static::Event.in_file(@file_path.to_s, document: @document).first
      end

      def series
        @series ||= event.series
      end

      def missing_fields
        return [] unless applicable?
        return [] unless series

        event_values = event.to_h
        series_values = series.to_h

        ACCOUNT_FIELDS.select do |field|
          event_values[field].to_s.strip.present? && series_values[field].to_s.strip.blank?
        end
      end

      def conflicting_sibling?(field)
        value = normalize(event[field])

        series.events.any? do |sibling|
          next false if sibling.file_path == File.expand_path(@file_path.to_s)

          sibling_value = normalize(sibling[field])
          sibling_value.present? && sibling_value != value
        end
      end

      def normalize(value)
        value.to_s.strip.downcase.delete_prefix("@").delete_suffix("/")
      end
    end
  end
end
