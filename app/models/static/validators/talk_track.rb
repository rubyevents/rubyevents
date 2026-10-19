# frozen_string_literal: true

module Static
  module Validators
    # Makes sure every track used in a videos.yml is defined in the tracks of
    # the sibling schedule.yml. Otherwise the schedule shows the talk without
    # its track color.
    #
    # Events without a schedule.yml have nothing to match against and are skipped.
    # Tracks defined in the schedule but unused in videos.yml are allowed.
    class TalkTrack
      PATTERNS = [
        "**/videos.yml"
      ].freeze

      def initialize(file_path:, document: nil)
        @file_path = file_path
        @document = document
      end

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
        return [] unless schedule

        videos_file.pairs.flat_map do |video, nested|
          talk_errors(video) + nested.flat_map { |talk| talk_errors(talk) }
        end
      end

      private

      def videos_file
        @videos_file ||= Static::Talk.in_file(@file_path, document: @document)
      end

      def schedule
        @schedule ||= videos_file.first&.event&.schedule
      end

      def schedule_tracks
        @schedule_tracks ||= Array(schedule["tracks"]).filter_map { |track| track["name"] }
      end

      def talk_errors(node)
        track = node["track"].to_s
        return [] if track.empty? || schedule_tracks.include?(track)

        defined_tracks = schedule_tracks.any? ? schedule_tracks.map { |name| "\"#{name}\"" }.join(", ") : "none"
        location = node.source_location("track")

        [
          Static::Validators::Error.new(
            "track \"#{track}\" is not defined in the tracks of schedule.yml (defined: #{defined_tracks}). Fix the track name or add it to the tracks in schedule.yml.",
            file_path: @file_path,
            line: location&.start_line || 1,
            end_line: location&.end_line
          )
        ]
      end
    end
  end
end
