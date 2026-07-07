# frozen_string_literal: true

module Static
  module Validators
    class UniqueTalkIds
      PATTERNS = ["**/videos.yml"].freeze

      KEYS = %w[id old_id].freeze

      def initialize(file_path:)
        @file_path = file_path.to_s.sub("#{Rails.root}/", "")
      end

      def applicable?
        return false unless File.exist?(@file_path)

        PATTERNS.any? do |pattern|
          File.fnmatch?(pattern, @file_path, File::FNM_PATHNAME)
        end
      end

      def errors
        return [] unless applicable?

        self.class.errors.select { |error| error.file_path == @file_path }
      end

      def self.errors
        @errors ||= duplicate_errors(files: Static::VideosFile.all)
      end

      def self.reset!
        @errors = nil
      end

      def self.duplicate_errors(files:)
        references = files.flat_map do |file|
          file.talks.flat_map do |node|
            KEYS.filter_map do |key|
              scalar = node[key]
              next unless scalar

              {
                key: key,
                value: scalar.value,
                file: file.relative_path,
                line: scalar.location&.start_line || 1,
                end_line: scalar.location&.end_line
              }
            end
          end
        end

        references.group_by { |reference| reference[:value] }.select { |_value, refs| refs.many? }.flat_map do |value, refs|
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
    end
  end
end
