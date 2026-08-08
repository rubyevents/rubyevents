# frozen_string_literal: true

module Static
  module Validators
    class UniqueSpeakers
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

        speakers = Static::SpeakersFile.new(@file_path, document: @document)
        errors = []

        errors += validate_same_name_duplicates(speakers)
        errors += validate_reversed_name_duplicates(speakers)

        errors
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
