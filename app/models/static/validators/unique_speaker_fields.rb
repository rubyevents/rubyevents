# frozen_string_literal: true

module Static
  module Validators
    class UniqueSpeakerFields
      def initialize(file_path:)
        @file_path = file_path
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
          File.fnmatch?(pattern, @file_path, File::FNM_PATHNAME)
        end
      end

      def errors
        @errors ||= validate
      end

      def validate
        return [] unless applicable?

        speakers = Static::SpeakersFile.new(@file_path)
        errors = []

        UNIQUE_FIELDS.each do |field|
          speakers.duplicates(field).each do |value, count|
            location = speakers.document.find_by("#{field}": value)&.location

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
        doc = speakers.document
        names = doc.value_at("[].name")
        main_slugs = doc.value_at("[].slug")
        aliases_data = doc.value_at("[].aliases")
        main_slug_owners = {}

        main_slugs.zip(names).each do |slug, name|
          main_slug_owners[slug] = name if slug
        end

        alias_slug_owners = Hash.new { |h, k| h[k] = Set.new }

        names.zip(aliases_data).each do |speaker_name, speaker_aliases|
          next if speaker_aliases.nil?

          Array(speaker_aliases).each do |a|
            alias_slug_owners[a["slug"]] << speaker_name if a["slug"]
          end
        end

        errors = []

        alias_slug_owners.select { |_, owners| owners.size > 1 }.each do |slug, owners|
          location = doc.find_by(slug: slug)&.location

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

          location = doc.find_by(slug: slug)&.location

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
