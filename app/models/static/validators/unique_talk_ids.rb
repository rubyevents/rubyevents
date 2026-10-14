# frozen_string_literal: true

module Static
  module Validators
    class UniqueTalkIds
      PATTERNS = ["**/videos.yml"].freeze

      KEYS = %w[id old_id].freeze

      def initialize(file_path:, document: nil)
        @file_path = file_path.to_s.sub("#{Rails.root}/", "")
      end

      def applicable?
        return false unless File.exist?(@file_path)

        PATTERNS.any? do |pattern|
          File.fnmatch?(pattern, @file_path, File::FNM_PATHNAME | File::FNM_DOTMATCH)
        end
      end

      def errors
        return [] unless applicable?

        self.class.errors.select { |error| error.file_path == @file_path }
      end

      def self.errors
        talks = Static::Talk.all
        return @errors if @talks.equal?(talks)

        @talks = talks
        @errors = duplicate_errors(talks)
      end

      def self.warmup
        errors
      end

      def self.duplicate_errors(talks)
        references = talks.flat_map do |talk|
          KEYS.filter_map { |key| {key: key, value: talk[key], talk: talk} if talk[key].present? }
        end

        references.group_by { |reference| reference[:value] }.select { |_value, refs| refs.many? }.flat_map do |value, refs|
          refs.each { |reference| locate(reference) }

          refs.map do |reference|
            others = (refs - [reference]).map { |other| "#{other[:file]}:#{other[:line]}" }.join(", ")

            Static::Validators::Error.new(
              %(#{reference[:key]} "#{value}" is not unique across talks, it is also used at #{others}),
              file_path: reference[:file],
              line: reference[:line],
              end_line: reference[:end_line]
            )
          end
        end
      end

      def self.locate(reference)
        location = reference[:talk].source_location(reference[:key])

        reference[:file] = reference[:talk].file_path.to_s.sub("#{Rails.root}/", "")
        reference[:line] = location&.start_line || 1
        reference[:end_line] = location&.end_line
      end
    end
  end
end
