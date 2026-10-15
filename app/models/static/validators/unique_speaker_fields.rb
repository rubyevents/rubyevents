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
            location = speakers.document.find_by("#{field}": value)&.location

            errors << Static::Validators::Error.new(
              "Duplicate #{field}: #{value} (#{count} occurrences)",
              file_path: @file_path,
              line: location&.start_line || 1,
              end_line: location&.end_line
            )
          end
        end

        errors + validate_redirect_slugs(speakers)
      end

      private

      def validate_redirect_slugs(speakers)
        doc = speakers.document
        names = doc.value_at("[].name")
        main_slugs = doc.value_at("[].slug")
        githubs = doc.value_at("[].github")
        github_handles = doc.value_at("[].github_handles")
        redirect_slugs = doc.value_at("[].slugs")

        owners = Hash.new { |hash, key| hash[key] = Set.new }

        names.each_with_index do |name, index|
          owners[main_slugs[index]] << name if main_slugs[index].present?
        end

        errors = []

        names.each_with_index do |name, index|
          handles = [githubs[index], *Array(github_handles[index])].compact_blank

          Array(redirect_slugs[index]).each do |redirect_slug|
            other_owners = owners[redirect_slug] - [name]
            location = doc.find_by(name: name)&.location

            message = if handles.any? { |handle| redirect_slug.casecmp?(handle) }
              "Slug '#{redirect_slug}' in slugs of '#{name}' is redundant, it's the GitHub handle of the speaker and profile URLs already resolve GitHub handles"
            elsif owners[redirect_slug].include?(name)
              "Slug '#{redirect_slug}' in slugs of '#{name}' is redundant, it's already the slug of the speaker"
            elsif other_owners.any?
              "Slug '#{redirect_slug}' in slugs of '#{name}' is already used by #{other_owners.to_a.join(", ")}"
            end

            owners[redirect_slug] << name

            next unless message

            errors << Static::Validators::Error.new(message, file_path: @file_path, line: location&.start_line || 1, end_line: location&.end_line)
          end
        end

        errors
      end
    end
  end
end
