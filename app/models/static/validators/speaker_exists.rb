# frozen_string_literal: true

module Static
  module Validators
    class SpeakerExists
      PATTERNS = ["**/videos.yml"].freeze
      KNOWN_NAMES = Static::SpeakersFile.new.known_names.freeze

      def initialize(file_path:)
        @file_path = file_path
      end

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

        errors = []
        document = Yerba.parse_file(@file_path)

        Array(document).each_with_index do |video, index|

          Array(document["[#{index}]"]["speakers"]).each_with_index do |name, index|
            unless KNOWN_NAMES.include?(name.to_s)
              binding.irb
              location = document["[#{index}]"]["speakers"][index.to_s]&.location

              errors << Static::Validators::Error.new(
                "Speaker '#{name}' not found in speakers.yml",
                file_path: @file_path,
                line: location&.start_line || 1,
                end_line: location&.end_line
              )
            end
          end

          Array(video["talks"]).each do |talk|
            Array(talk["speakers"]).each do |name|
              unless KNOWN_NAMES.include?(name)
                errors << Static::Validators::Error.new(
                  "Speaker '#{name}' not found in speakers.yml",
                  file_path: @file_path,
                  line: 1,
                  end_line: 1
                )
              end
            end
          end
        end

        errors
      end
    end
  end
end
