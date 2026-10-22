# frozen_string_literal: true

module Static
  module Validators
    class MeetupTalksNested
      PATTERNS = [
        "**/videos.yml"
      ].freeze

      def initialize(file_path:, document: nil)
        @file_path = file_path
        @document = document
      end

      def applicable?
        return false unless File.exist?(@file_path)

        matches = PATTERNS.any? do |pattern|
          File.fnmatch?(pattern, @file_path, File::FNM_PATHNAME | File::FNM_DOTMATCH)
        end

        matches && event&.meetup? && !MeetupNaming.ignored?(event)
      end

      def errors
        @errors ||= validate
      end

      def validate
        return [] unless applicable?

        top_level_talks.map do |talk|
          location = talk.source_location("id")

          Static::Validators::Error.new(
            %(talk "#{talk["title"]}" is listed as a meetup edition. Nest it under the "children" edition for #{talk["date"]} ("#{edition_title(talk)}") in `talks`, like the other talks of a meetup.),
            file_path: @file_path,
            line: location&.start_line || 1,
            end_line: location&.end_line
          )
        end
      end

      private

      # Speakers of "TODO" stay unflagged, some groups use it on editions whose talks aren't known yet.
      def top_level_talks
        videos_file.to_a.select do |node|
          speakers = Array(node["speakers"])

          node.parent.nil? && speakers.any? && speakers != ["TODO"] && node["video_provider"] != "children"
        end
      end

      def edition_title(talk)
        date = Date.iso8601(talk["date"].to_s)

        "#{event["title"]} #{date.strftime("%B")} #{date.year}"
      rescue Date::Error
        event["title"]
      end

      def videos_file
        @videos_file ||= Static::Talk.in_file(@file_path, document: @document)
      end

      def event
        @event ||= videos_file.to_a.first&.event
      end
    end
  end
end
