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
          File.fnmatch?(pattern, @file_path, File::FNM_PATHNAME)
        end
      end

      def errors
        @errors ||= validate
      end

      def validate
        return [] unless applicable?

        @talks_by_time = talks.group_by { |talk| [talk.value_at("date"), talk.value_at("start_time"), talk.value_at("end_time")] }

        grid_rows.filter_map { |day, row| error_for(day, row) }
      end

      private

      def document
        @document ||= Yerba.parse_file(@file_path.to_s)
      end

      # Every grid row of every day, as [day, row] pairs.
      def grid_rows
        return @grid_rows if defined?(@grid_rows)

        @grid_rows = []

        document["days"]&.each do |day|
          day["grid"]&.each do |row|
            @grid_rows << [day, row]
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
          Static::VideosFile.new(videos_path).top_level_talks
        else
          []
        end
      end

      def error_for(day, row)
        unclaimed_slots_left = unclaimed_slots_left(day, row)

        case unclaimed_slots_left
        when (..-1)
          error(
            row,
            "#{row_name(day, row)} has #{-unclaimed_slots_left} too many items. Update the slot count, remove items from the schedule.yml, or reschedule talks in the videos.yml."
          )
        when (1...)
          error(
            row,
            "#{row_name(day, row)} has #{unclaimed_slots_left} unfilled #{"slot".pluralize(unclaimed_slots_left)}. Fix by lowering the slot count, adding talks to the videos.yml, or removing items from the schedule.yml."
          )
        end
      end

      def unclaimed_slots_left(day, row)
        slots_left = row.value_at("slots")
        slots_left -= row["items"]&.length.to_i
        scheduled_talks_count = @talks_by_time[[day.value_at("date"), row.value_at("start_time"), row.value_at("end_time")]]&.count || 0
        slots_left -= scheduled_talks_count
        unscheduled_talks = untimed_talks(day)&.shift(slots_left) if slots_left.positive?
        slots_left -= unscheduled_talks&.count || 0

        slots_left
      end

      # Talks without a start_time and end_time can fill any slot on their date.
      def untimed_talks(day)
        @talks_by_time[[day.value_at("date"), nil, nil]]
      end

      def row_name(day, row)
        time = "#{row.value_at("start_time")}-#{row.value_at("end_time")}"
        day_label = day.value_at("name") || day.value_at("date")

        "slots (#{row.value_at("slots")}) at #{time} on \"#{day_label}\""
      end

      def error(node, message)
        location = node.location

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
