# frozen_string_literal: true

module Static
  module Validators
    class TalkPublishedAt
      PATTERNS = [
        "**/videos.yml"
      ].freeze

      PROVIDERS_WITHOUT_PUBLISHED_AT = (Talk::UNPUBLISHED_PROVIDERS + ["children", "parent"]).freeze
      SCOPES = ["[]", "[].talks[]"].freeze

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
          @errors ||= SCOPES.flat_map { |scope| errors_in(scope) }
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

        private

        def errors_in(scope)
          providers = values_at(scope, "video_provider")

          scalars_at(scope, "published_at").filter_map do |scalar|
            next if scalar.value.to_s.strip.empty?

            provider = providers[entry_key(scalar)]
            next unless PROVIDERS_WITHOUT_PUBLISHED_AT.include?(provider)

            Static::Validators::Error.new(
              "published_at (#{scalar.value}) must not be set when video_provider is \"#{provider}\"",
              file_path: scalar.file_path,
              line: scalar.location&.start_line || 1,
              end_line: scalar.location&.end_line
            )
          end
        end

        def values_at(scope, field)
          scalars_at(scope, field).to_h { |scalar| [entry_key(scalar), scalar.value] }
        end

        def scalars_at(scope, field)
          Array(Yerba::Collection.get(glob, "#{scope}.#{field}"))
        end

        def entry_key(scalar)
          [scalar.file_path, scalar.selector.rpartition(".").first]
        end
      end
    end
  end
end
