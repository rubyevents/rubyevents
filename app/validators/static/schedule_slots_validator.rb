# frozen_string_literal: true

module Static
  # Walks the grid of a schedule.yml and makes sure every slot is backed by either a talk from
  # videos.yml or an item listed in the row itself.
  #
  # Rows without `items` consume talks from the top level entries of videos.yml, in file order.
  # If talks have a start_time and end_time that matches a slot, they can only be used on that slot.
  #
  class ScheduleSlotsValidator < ActiveModel::Validator
    def validate(schedule)
      talks = schedule.event&.talks&.top_level.to_a
      talks_by_time = talks.group_by { |talk| [talk["date"], talk["start_time"], talk["end_time"]] }

      Array(schedule["days"]).each_with_index do |day, day_index|
        Array(day["grid"]).each_with_index do |row, row_index|
          left = slots_left(talks_by_time, day, row)
          at = "days[#{day_index}].grid[#{row_index}]"

          if left.negative?
            schedule.errors.add(:base, "#{row_name(day, row)} has #{-left} too many items. Update the slot count, remove items from the schedule.yml, or reschedule talks in the videos.yml.", at: at)
          elsif left.positive?
            schedule.errors.add(:base, "#{row_name(day, row)} has #{left} unfilled #{"slot".pluralize(left)}. Fix by lowering the slot count, adding talks to the videos.yml, or removing items from the schedule.yml.", at: at)
          end
        end
      end
    end

    private

    def slots_left(talks_by_time, day, row)
      left = row["slots"].to_i - row["items"]&.length.to_i
      left -= talks_by_time[[day["date"], row["start_time"], row["end_time"]]]&.count || 0

      # Talks without a start_time and end_time can fill any slot on their date
      left -= talks_by_time[[day["date"], nil, nil]]&.shift(left)&.count || 0 if left.positive?

      left
    end

    def row_name(day, row)
      %(slots (#{row["slots"]}) at #{row["start_time"]}-#{row["end_time"]} on "#{day["name"] || day["date"]}")
    end
  end
end
