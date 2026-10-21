# frozen_string_literal: true

module Static
  module Validators
    class SpeakerSlugMatchesName
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

        speakers.filter_map do |speaker|
          name = speaker["name"].to_s
          expected_slug = name.parameterize
          next if speaker["slug"] == expected_slug

          location = speaker.source_location("slug") || speaker.source_location

          message = if expected_slug.empty?
            github = speaker["github"]
            suggestion = github.present? ? %(a romanized name, or the GitHub handle "#{github}" if none is known,) : "a romanized name"

            %(Name "#{name}" cannot be parameterized into a stable slug. Use #{suggestion} as the name and add "#{name}" to aliases.)
          else
            "Slug must be the name parameterized, expected: #{expected_slug}"
          end

          Static::Validators::Error.new(
            message,
            file_path: @file_path,
            line: location&.start_line || 1,
            end_line: location&.end_line
          )
        end
      end

      # Uses the GitHub handle as the name when the name can't be parameterized, keeping the old
      # name as an alias, and regenerates mismatched slugs. Changed slugs stay redirects in slugs.
      def fix
        return unless applicable?

        changed = speakers.count do |speaker|
          name = speaker["name"].to_s
          github = speaker["github"].to_s
          slug = speaker["slug"].to_s
          renamed = false

          if name.parameterize.empty?
            next false if github.parameterize.empty?

            speaker["aliases"] = [name, *speaker.alias_names].uniq
            speaker["name"] = github
            name = github
            renamed = true
          end

          expected_slug = name.parameterize
          next renamed if slug == expected_slug

          if slug.present? && !slug.casecmp?(github)
            speaker["slugs"] = (speaker.redirect_slugs + [slug]).uniq
          end

          speaker["slug"] = expected_slug
          true
        end

        return if changed.zero?

        speakers.save!

        {changed: changed, file_path: @file_path}
      end

      private

      def speakers
        @speakers ||= Static::Speaker.in_file(@file_path.to_s, document: @document)
      end
    end
  end
end
