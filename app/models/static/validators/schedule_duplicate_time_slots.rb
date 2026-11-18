# frozen_string_literal: true

module Static
  module Validators
    # Makes sure no two grid rows of the same day in a schedule.yml share the
    # same start_time and end_time. Parallel sessions belong in one row with a
    # higher slot count.
    #
    # Rows with items and rows filled by talks from videos.yml are compared
    # separately, since a single row can't mix both.
    #
    # Duplicate rows that sit next to each other and only differ in slots and
    # items can be merged with `bin/rails validate:fix`.
    #
    class ScheduleDuplicateTimeSlots
      PATTERNS = [
        "**/schedule.yml"
      ].freeze

      MERGEABLE_KEYS = %w[slots items].freeze

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

        duplicate_groups.flat_map do |rows|
          first, *duplicates = rows

          duplicates.map { |row| error(row, first, mergeable?(rows)) }
        end
      end

      def fix
        return unless applicable?

        groups = duplicate_groups.select { |rows| mergeable?(rows) }
        return if groups.empty?

        groups.reverse_each { |first, *duplicates| merge(first, duplicates) }

        schedule.save!

        {changed: groups.sum { |rows| rows.size - 1 }, file_path: @file_path}
      end

      private

      def schedule
        @schedule ||= Static::Schedule.in_file(@file_path.to_s, document: @document).first
      end

      def duplicate_groups
        @duplicate_groups ||= schedule.days.flat_map do |day|
          day.grid.group_by { |row| [row["start_time"], row["end_time"], items_row?(row)] }.values.select { |rows| rows.size > 1 }
        end
      end

      def mergeable?(rows)
        adjacent = rows.map(&:index).each_cons(2).all? { |a, b| b == a + 1 }
        same_details = rows.map { |row| row.to_h.except(*MERGEABLE_KEYS) }.uniq.one?

        adjacent && same_details
      end

      def merge(first, duplicates)
        first["slots"] = [first, *duplicates].sum { |row| row_slots(row) }

        move_items(duplicates, into: first) if items_row?(first)

        duplicates.reverse_each(&:destroy)
      end

      def move_items(duplicates, into:)
        document = schedule.document
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

      def error(row, first, mergeable)
        day_label = row.day["name"] || row.day["date"]
        location = row.source_location

        hint =
          if mergeable
            "Merge them into one row with a higher slot count. Run `bin/rails validate:fix` to merge them."
          else
            "Fix the time if it's a typo, or merge them into one row with a higher slot count."
          end

        Static::Validators::Error.new(
          %(slots at #{row["start_time"]}-#{row["end_time"]} on "#{day_label}" repeat the start_time and end_time of the row on line #{first.source_line}. #{hint}),
          file_path: @file_path,
          line: location&.start_line || 1,
          end_line: location&.end_line
        )
      end
    end
  end
end
