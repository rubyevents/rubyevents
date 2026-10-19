# frozen_string_literal: true

module Static
  module Validators
    # Walks the grid of a schedule.yml and makes sure every slot is backed by
    # either a talk from videos.yml or an item listed in the row itself.
    #
    # Rows without `items` consume talks from the top level entries of
    # videos.yml, in file order.
    # If talks have a start_time and end_time that matches a slot,
    # they can only be used on that slot.
    class ScheduleSlotsFilled
      PATTERNS = [
        "**/schedule.yml"
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

        @talks_by_time = talks.group_by { |talk| [talk["date"], talk["start_time"], talk["end_time"]] }

        grid_rows.filter_map { |day, row, location| error_for(day, row, location) }
      end

      private

      def schedule
        @schedule ||= Static::Schedule.in_file(@file_path.to_s, document: @document).first
      end

      # Every grid row of every day, as [day, row, location] triples.
      def grid_rows
        return @grid_rows if defined?(@grid_rows)

        @grid_rows = []

        Array(schedule["days"]).each_with_index do |day, day_index|
          Array(day["grid"]).each_with_index do |row, row_index|
            @grid_rows << [day, row, schedule.source_location("days[#{day_index}].grid[#{row_index}]")]
          end
        end

        @grid_rows
      end

      def videos_path
        File.join(File.dirname(@file_path.to_s), "videos.yml")
      end

      # The talks a schedule can draw from: the top level entries of videos.yml,
      # the same ones Event::Schedule#sessions walks in running order.
      def talks
        return @talks if defined?(@talks)

        @talks = if File.exist?(videos_path)
          Static::Talk.in_file(videos_path).top_level.to_a
        else
          []
        end
      end

      def error_for(day, row, location)
        unclaimed_slots_left = unclaimed_slots_left(day, row)

        case unclaimed_slots_left
        when (..-1)
          error(
            location,
            "#{row_name(day, row)} has #{-unclaimed_slots_left} too many items. Update the slot count, remove items from the schedule.yml, or reschedule talks in the videos.yml."
          )
        when (1...)
          error(
            location,
            "#{row_name(day, row)} has #{unclaimed_slots_left} unfilled #{"slot".pluralize(unclaimed_slots_left)}. Fix by lowering the slot count, adding talks to the videos.yml, or removing items from the schedule.yml."
          )
        end
      end

      def unclaimed_slots_left(day, row)
        slots_left = row["slots"]
        slots_left -= row["items"]&.length.to_i
        scheduled_talks_count = @talks_by_time[[day["date"], row["start_time"], row["end_time"]]]&.count || 0
        slots_left -= scheduled_talks_count
        unscheduled_talks = untimed_talks(day)&.shift(slots_left) if slots_left.positive?
        slots_left -= unscheduled_talks&.count || 0

        slots_left
      end

      # Talks without a start_time and end_time can fill any slot on their date.
      def untimed_talks(day)
        @talks_by_time[[day["date"], nil, nil]]
      end

      def row_name(day, row)
        time = "#{row["start_time"]}-#{row["end_time"]}"
        day_label = day["name"] || day["date"]

        "slots (#{row["slots"]}) at #{time} on \"#{day_label}\""
      end

      def error(location, message)
        Static::Validators::Error.new(
          message,
          file_path: @file_path,
          line: location&.start_line || 1,
          end_line: location&.end_line
        )
      end
    end
  end
end
