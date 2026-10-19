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

        identifiers = Hash.new { |hash, key| hash[key] = [] }

        Static::Speaker.in_file(@file_path.to_s, document: @document).each do |speaker|
          name = speaker["name"]
          github = speaker["github"]

          identifiers[name.downcase] << {value: name, kind: "name", speaker: name, record: speaker} if name.present?
          identifiers[github.downcase] << {value: github, kind: "GitHub handle", speaker: name, record: speaker} if github.present?

          Array(speaker["aliases"]).each do |alias_entry|
            next unless alias_entry.is_a?(Hash)

            alias_name = alias_entry["name"]
            identifiers[alias_name.downcase] << {value: alias_name, kind: "alias", speaker: name, record: speaker} if alias_name.present?
          end
        end

        identifiers.values.filter_map do |uses|
          next if uses.map { |use| use[:speaker] }.uniq.size < 2

          location = uses.last[:record].source_location
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
