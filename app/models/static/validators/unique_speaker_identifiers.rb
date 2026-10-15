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
          identifiers[name.downcase] << {value: name, kind: "name", speaker: name} if name.present?
          identifiers[githubs[index].downcase] << {value: githubs[index], kind: "GitHub handle", speaker: name} if githubs[index].present?

          Array(aliases[index]).each do |alias_entry|
            alias_name = alias_entry["name"] if alias_entry.is_a?(Hash)
            identifiers[alias_name.downcase] << {value: alias_name, kind: "alias", speaker: name} if alias_name.present?
          end
        end

        identifiers.values.filter_map do |uses|
          next if uses.map { |use| use[:speaker] }.uniq.size < 2

          location = @document.find_by(name: uses.last[:speaker])&.location
          description = uses.map { |use| %(#{use[:kind]} "#{use[:value]}" of "#{use[:speaker]}") }.join(", ")

          Static::Validators::Error.new(
            "Speaker identifier used by more than one speaker: #{description}. Names, aliases, and GitHub handles must each identify a single speaker.",
            file_path: @file_path,
            line: location&.start_line || 1,
            end_line: location&.end_line
          )
        end
      end
    end
  end
end
