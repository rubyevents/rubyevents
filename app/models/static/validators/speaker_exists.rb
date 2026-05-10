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

        index = 0
        loop do
          speakers = document.at_path("[].speakers[#{index}]")
          break if speakers.empty?
          speakers.each do |speaker|
            name = speaker&.value
            next if name.blank? || KNOWN_NAMES.include?(name)
            location = speaker&.location
            errors << Static::Validators::Error.new(
              "Speaker '#{name}' not found in speakers.yml",
              file_path: @file_path,
              line: location&.start_line || 1,
              end_line: location&.end_line
            )
          end
          index += 1
        end

        video_index, talk_index, speakers_index = 0, 0, 0
        loop do
          videos = document["[#{video_index}]"]
          talks = document["[#{video_index}].talks[#{talk_index}]"]
          talk_speakers = document["[#{video_index}].talks[#{talk_index}].speakers[#{speakers_index}]"]
          if videos.nil?
            break
          elsif talks.nil?
            video_index += 1
            talk_index = 0
            speakers_index = 0
            next
          elsif talk_speakers.nil?
            talk_index += 1
            speakers_index = 0
            next
          end
          name = talk_speakers.value
          unless name.blank? || KNOWN_NAMES.include?(name)
            location = talk_speakers.location
            errors << Static::Validators::Error.new(
              "Speaker '#{name}' not found in speakers.yml",
              file_path: @file_path,
              line: location&.start_line || 1,
              end_line: location&.end_line
            )
          end
          speakers_index += 1
        end

        errors
      end
    end
  end
end
