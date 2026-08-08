# frozen_string_literal: true

module Static
  module Validators
    class UniqueTalkIds
      PATTERNS = ["**/videos.yml"].freeze

      KEYS = %w[id old_id].freeze
      SCOPES = ["[]", "[].talks[]"].freeze
      SELECTOR = /\A\[(\d+)\](?:\.talks\[(\d+)\])?\.(#{Regexp.union(KEYS)})\z/

      def initialize(file_path:, document: nil)
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

      class << self
        def errors
          @errors ||= errors_from(collection_references)
        end

        def warmup
          errors
        end

        def reset!
          @errors = nil
          remove_instance_variable(:@glob) if defined?(@glob)
        end

        attr_writer :glob

        def glob
          @glob ||= Rails.root.join(Static::VideosFile::VIDEOS_GLOB).to_s
        end

        def duplicate_errors(files:)
          errors_from(file_references(files))
        end

        private

        def collection_references
          order = Dir.glob(glob).each_with_index.to_h

          SCOPES.flat_map { |scope|
            KEYS.flat_map { |key| Array(Yerba::Collection.get(glob, "#{scope}.#{key}")) }
          }.filter_map { |scalar| collection_reference(scalar, order) }.sort_by { |reference| reference[:order] }
        end

        def collection_reference(scalar, order)
          match = SELECTOR.match(scalar.selector.to_s)
          return nil unless match

          index = match[1].to_i
          nested = match[2]&.to_i

          {
            key: match[3],
            value: scalar.value,
            file: scalar.file_path.sub("#{Rails.root}/", ""),
            line: scalar.location&.start_line || 1,
            end_line: scalar.location&.end_line,
            order: [order.fetch(scalar.file_path, Float::INFINITY), nested ? 1 : 0, index, nested || -1, KEYS.index(match[3])]
          }
        end

        def file_references(files)
          files.flat_map do |file|
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
        end

        def errors_from(references)
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
end
