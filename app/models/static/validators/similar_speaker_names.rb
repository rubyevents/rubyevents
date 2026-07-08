# frozen_string_literal: true

module Static
  module Validators
    class SimilarSpeakerNames
      def initialize(file_path:, document: nil)
        @file_path = file_path
        @document = document
      end

      PATTERNS = [
        "**/speakers.yml"
      ].freeze

      SIMILARITY_THRESHOLD = 0.85

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

        speakers = Static::SpeakersFile.new(@file_path, document: @document)
        clusters = speakers.near_duplicate_names(threshold: SIMILARITY_THRESHOLD)
        return [] if clusters.empty?

        clusters.flat_map do |cluster|
          cluster.names.filter_map do |name|
            next if speakers.social_handle?(name)

            others = cluster.names - [name]
            location = speakers.document.find_by(name: name)&.location

            Static::Validators::Error.new(
              "#{name.inspect} closely matches #{others.map(&:inspect).join(", ")} but has no social handle " \
              "(#{Static::SpeakersFile::SOCIAL_HANDLE_FIELDS.join(", ")}). Add one to disambiguate whether they are the same person.",
              file_path: @file_path,
              line: location&.start_line || 1,
              end_line: location&.end_line
            )
          end
        end
      end
    end
  end
end
