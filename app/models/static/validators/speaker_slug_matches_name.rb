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

        errors = []

        @document ||= Yerba.parse_file(@file_path)
        name_slug_pairs = @document.pluck(:name).zip(@document.pluck(:slug), @document.pluck(:github))
        errors.concat(find_errors_for_name_slug_pairs(name_slug_pairs) do |name|
          @document.find_by(name: name)&.[]("slug")
        end)

        errors
      end

      def fix
        return unless applicable?

        @document ||= Yerba.parse_file(@file_path)
        changed = 0

        @document.root.each do |speaker|
          name = speaker["name"].value.to_s
          github = speaker["github"]&.value.to_s
          slug = speaker["slug"]&.value.to_s
          renamed = false

          if name.parameterize.empty?
            next if github.blank? || github.parameterize.empty?

            aliases = speaker["aliases"]&.map(&:value) || []
            speaker["name"] = github
            speaker["aliases"] = [name, *aliases].uniq
            name = github
            renamed = true
          end

          expected_slug = name.parameterize

          if slug == expected_slug
            changed += 1 if renamed
            next
          end

          if slug.present? && slug != expected_slug
            redirect_slugs = speaker["slugs"]&.map(&:value) || []
            speaker["slugs"] = (redirect_slugs + [slug]).uniq unless github.present? && slug.casecmp?(github)
          end

          speaker["slug"] = expected_slug
          changed += 1
        end

        return if changed.zero?

        @document.save!(apply: true)

        {changed: changed, file_path: @file_path}
      end

      private

      def find_errors_for_name_slug_pairs(name_slug_pairs, &block)
        name_slug_pairs.filter_map do |name, slug, github|
          expected_slug = name.parameterize
          next if slug == expected_slug

          entry = block.call(name)

          if expected_slug.empty?
            suggestion = github.present? ? %(a romanized name, or the GitHub handle "#{github}" if none is known,) : "a romanized name"

            Static::Validators::Error.new(
              %(Name "#{name}" cannot be parameterized into a stable slug. Use #{suggestion} as the name and add "#{name}" to aliases.),
              file_path: @file_path,
              line: entry&.location&.start_line || 1,
              end_line: entry&.location&.end_line
            )
          else
            Static::Validators::Error.new(
              "Slug must be the name parameterized, expected: #{expected_slug}",
              file_path: @file_path,
              line: entry&.location&.start_line || 1,
              end_line: entry&.location&.end_line
            )
          end
        end
      end
    end
  end
end
