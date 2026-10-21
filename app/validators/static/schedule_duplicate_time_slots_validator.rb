# frozen_string_literal: true

module Static
  # No two grid rows of the same day share the same start_time and end_time. Parallel sessions belong in one row
  # with a higher slot count.
  #
  # Rows with items and rows filled by talks from videos.yml are compared separately, since a single row can't
  # mix both. Duplicate rows that sit next to each other and only differ in slots and items can be merged with
  # `bin/rails validate:fix`.
  #
  class ScheduleDuplicateTimeSlotsValidator < ActiveModel::Validator
    MERGEABLE_KEYS = %w[slots items].freeze

    def validate(schedule)
      duplicate_groups(schedule).each do |rows|
        first, *duplicates = rows
        mergeable = mergeable?(rows)

        duplicates.each do |row|
          hint = if mergeable
            "Merge them into one row with a higher slot count. Run `bin/rails validate:fix` to merge them."
          else
            "Fix the time if it's a typo, or merge them into one row with a higher slot count."
          end

          schedule.errors.add(:base, %(slots at #{row["start_time"]}-#{row["end_time"]} on "#{row.day["name"] || row.day["date"]}" repeat the start_time and end_time of the row on line #{first.source_line}. #{hint}), at: row.selector)
        end
      end
    end

    def fix(schedule)
      groups = duplicate_groups(schedule).select { |rows| mergeable?(rows) }

      # Later rows first, so removing them doesn't shift the rows still to merge
      groups.reverse_each { |first, *duplicates| merge(schedule, first, duplicates) }

      groups.sum { |rows| rows.size - 1 }
    end

    private

    def duplicate_groups(schedule)
      schedule.days.flat_map do |day|
        day.grid.group_by { |row| [row["start_time"], row["end_time"], items_row?(row)] }.values.select(&:many?)
      end
    end

    def mergeable?(rows)
      adjacent = rows.map(&:index).each_cons(2).all? { |a, b| b == a + 1 }
      same_details = rows.map { |row| row.to_h.except(*MERGEABLE_KEYS) }.uniq.one?

      adjacent && same_details
    end

    def merge(schedule, first, duplicates)
      first["slots"] = [first, *duplicates].sum { |row| row_slots(row) }

      move_items(schedule.document, duplicates, into: first) if items_row?(first)

      duplicates.reverse_each(&:destroy)
    end

    # Copies the items over with the quote style of each of their strings
    def move_items(document, duplicates, into:)
      items_selector = "#{into.selector}.items"
      offset = document.length_at(items_selector)

      moved = duplicates.flat_map do |row|
        Array(row["items"]).each_index.map { |index| "#{row.selector}.items[#{index}]" }
      end

      styles = moved.map { |selector| scalar_styles(document, selector) }

      document[items_selector].concat(moved.map { |selector| document.value_at(selector) })

      styles.each_with_index do |item_styles, index|
        item_styles.each do |suffix, style|
          document["#{items_selector}[#{offset + index}]#{suffix}"].quote_style = style
        end
      end
    end

    def scalar_styles(document, selector)
      value = document.value_at(selector)
      suffixes = value.is_a?(Hash) ? value.filter_map { |key, v| ".#{key}" if v.is_a?(String) } : [""]

      suffixes.to_h { |suffix| [suffix, document["#{selector}#{suffix}"].quote_style] }
    end

    def items_row?(row)
      Array(row["items"]).any?
    end

    def row_slots(row)
      (row["slots"] || Array(row["items"]).size).to_i
    end
  end
end
