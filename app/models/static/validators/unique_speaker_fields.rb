# frozen_string_literal: true

module Static
  module Validators
    class UniqueSpeakerFields
      def initialize(file_path:, document: nil)
        @file_path = file_path
        @document = document
      end

      PATTERNS = [
        "**/speakers.yml"
      ].freeze

      UNIQUE_FIELDS = %w[
        slug
        github
        twitter
        speakerdeck
        mastodon
        bluesky
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

        speakers = Static::Speaker.in_file(@file_path, document: @document)
        errors = []

        UNIQUE_FIELDS.each do |field|
          speakers.duplicates(field).each do |value, count|
            location = speakers.find_by("#{field}": value)&.source_location

            errors << Static::Validators::Error.new(
              "Duplicate #{field}: #{value} (#{count} occurrences)",
              file_path: @file_path,
              line: location&.start_line || 1,
              end_line: location&.end_line
            )
          end
        end

        errors + validate_duplicate_alias_slugs(speakers)
      end

      private

      def validate_duplicate_alias_slugs(speakers)
        main_slug_owners = {}
        alias_slug_owners = Hash.new { |h, k| h[k] = Set.new }

        speakers.each do |speaker|
          main_slug_owners[speaker["slug"]] = speaker["name"] if speaker["slug"]

          Array(speaker["aliases"]).each do |a|
            alias_slug_owners[a["slug"]] << speaker["name"] if a["slug"]
          end
        end

        errors = []

        alias_slug_owners.select { |_, owners| owners.size > 1 }.each do |slug, owners|
          location = speakers.find_by(slug: slug)&.source_location

          errors << Static::Validators::Error.new(
            "Alias slug '#{slug}' shared across speakers: #{owners.to_a.join(", ")}",
            file_path: @file_path,
            line: location&.start_line || 1,
            end_line: location&.end_line
          )
        end

        alias_slug_owners.each do |slug, owners|
          main_owner = main_slug_owners[slug]
          next unless main_owner
          next if owners.size == 1 && owners.include?(main_owner)

          conflicting = owners.reject { |o| o == main_owner }
          next if conflicting.empty?

          location = speakers.find_by(slug: slug)&.source_location

          errors << Static::Validators::Error.new(
            "Alias slug '#{slug}' on #{conflicting.to_a.join(", ")} conflicts with main slug of '#{main_owner}'",
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
