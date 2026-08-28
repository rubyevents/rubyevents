# frozen_string_literal: true

module Static
  module Validators
    class RemovedTalkIds
      PATTERNS = [
        "**/event.yml"
      ].freeze

      def initialize(file_path:, document: nil)
        @file_path = file_path
        @document = document
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
        return [] if removed_talk_ids.nil?
        return [] unless File.exist?(videos_path)

        removed_talk_ids.filter_map do |item|
          id = item.value
          next unless known_ids.include?(id)

          Static::Validators::Error.new(
            %(id "#{id}" is listed under `removed_talk_ids`, but it is still in videos.yml. Either drop it from `removed_talk_ids`, or remove the talk from videos.yml.),
            file_path: @file_path,
            line: item.location&.start_line || 1,
            end_line: item.location&.end_line
          )
        end
      end

      private

      def document
        @document ||= Yerba.parse_file(@file_path)
      end

      def removed_talk_ids
        @removed_talk_ids ||= document["removed_talk_ids"]
      end

      def videos_file
        @videos_file ||= Static::VideosFile.new(videos_path)
      end

      def known_ids
        @known_ids ||= videos_file.ids + videos_file.old_ids
      end

      def videos_path
        @videos_path ||= File.join(File.dirname(@file_path.to_s), "videos.yml")
      end
    end
  end
end
