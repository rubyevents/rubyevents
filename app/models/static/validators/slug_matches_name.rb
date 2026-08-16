# frozen_string_literal: true

module Static
  module Validators
    class SlugMatchesName
      def initialize(file_path:, document: nil)
        @file_path = file_path
        @document = document
      end

      PATTERNS = [
        "**/speakers.yml"
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

        @document ||= Yerba.parse_file(@file_path)
        @document.root.filter_map do |speaker|
          errors = []

          if speaker["name"].to_s.parameterize != speaker["slug"].to_s.parameterize
            errors << Static::Validators::Error.new(
              "Slug must be the name parameterized, eg. first-lastname",
              file_path: @file_path,
              line: speaker.location&.start_line,
              end_line: speaker.location&.end_line
            )
          end

          speaker["aliases"]&.each do |alias_entry|
            next if alias_entry["name"].to_s.parameterize == alias_entry["slug"].to_s.parameterize
            errors << Static::Validators::Error.new(
              "Slug must be the name parameterized, eg. first-lastname",
              file_path: @file_path,
              line: alias_entry.location&.start_line,
              end_line: alias_entry.location&.end_line
            )
          end

          errors
        end.flatten
      end

      private

      def validate_same_name_duplicates(speakers)
        errors = []

        speakers.same_name_duplicates.each do |name, count|
          location = speakers.document.find_by(name: name)&.location
          location ||= speakers.document.find_by("aliases[].name" => name)&.location

          errors << Static::Validators::Error.new(
            "Same name duplicate: #{name} (#{count} occurrences)",
            file_path: @file_path,
            line: location&.start_line || 1,
            end_line: location&.end_line
          )
        end

        errors
      end

      def validate_reversed_name_duplicates(speakers)
        errors = []

        speakers.reversed_name_duplicates.each do |pair|
          location = speakers.document.find_by(name: pair[0])&.location
          location ||= speakers.document.find_by("aliases[].name" => pair[0])&.location

          errors << Static::Validators::Error.new(
            "Reversed name duplicate: #{pair[0]} ↔ #{pair[1]}",
            file_path: @file_path,
            line: location&.start_line || 1,
            end_line: location&.end_line
          )
        end

        errors
      end
    end
  end
end
