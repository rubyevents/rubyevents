# frozen_string_literal: true

module Static
  module Validators
    class UniqueSpeakerIdentifiers
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
          File.fnmatch?(pattern, @file_path, File::FNM_PATHNAME | File::FNM_DOTMATCH)
        end
      end

      def errors
        @errors ||= validate
      end

      def validate
        return [] unless applicable?

        @document ||= Yerba.parse_file(@file_path)

        names = @document.value_at("[].name")
        githubs = @document.value_at("[].github")
        aliases = @document.value_at("[].aliases")

        identifiers = Hash.new { |hash, key| hash[key] = [] }

        names.each_with_index do |name, index|
          identifiers[normalize(name)] << {value: name, kind: "name", speaker: name} if name.present?
          identifiers[normalize(githubs[index])] << {value: githubs[index], kind: "GitHub handle", speaker: name} if githubs[index].present?

          Array(aliases[index]).each do |alias_entry|
            next unless alias_entry.is_a?(Hash)

            alias_name = alias_entry["name"]
            identifiers[normalize(alias_name)] << {value: alias_name, kind: "alias", speaker: name} if alias_name.present?
          end
        end

        identifiers.values.flat_map do |uses|
          if uses.map { |use| use[:speaker] }.uniq.size > 1
            [shared_identifier_error(uses)]
          else
            case_variant_errors(uses)
          end
        end
      end

      private

      def normalize(value)
        value.to_s.strip.downcase
      end

      def shared_identifier_error(uses)
        description = uses.map { |use| %(#{use[:kind]} "#{use[:value]}" of "#{use[:speaker]}") }.join(", ")

        error(
          "Speaker identifier used by more than one speaker: #{description}. Names, aliases, and GitHub handles must each identify a single speaker.",
          uses.last[:speaker]
        )
      end

      def case_variant_errors(uses)
        names = uses.reject { |use| use[:kind] == "GitHub handle" }
        return [] if names.map { |use| use[:value] }.uniq.size < 2

        description = names.map { |use| %(#{use[:kind]} "#{use[:value]}") }.join(", ")

        [error(
          "Speaker names only differ in case or whitespace on \"#{names.first[:speaker]}\": #{description}. Name lookups ignore case and surrounding whitespace, so keep only one of them.",
          names.first[:speaker]
        )]
      end

      def error(message, speaker)
        location = @document.find_by(name: speaker)&.location

        Static::Validators::Error.new(
          message,
          file_path: @file_path,
          line: location&.start_line || 1,
          end_line: location&.end_line
        )
      end
    end
  end
end
