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

        duplicate_groups.flat_map do |group|
          first_index, *duplicate_indices = group[:row_indices]
          first_line = source_location(group[:day_index], first_index)&.start_line

          duplicate_indices.map do |row_index|
            error(group, row_index, first_line)
          end
        end
      end

      def fix
        return unless applicable?

        groups = duplicate_groups.select { |group| group[:mergeable] }
        return if groups.empty?

        # Merge from the bottom up so earlier row indices stay valid.
        groups.reverse_each { |group| merge_rows(group) }

        document.save!(apply: true)

        {changed: groups.sum { |group| group[:row_indices].size - 1 }, file_path: @file_path}
      end

      private

      def document
        @document ||= schedule.document
      end

      # Folds the duplicate rows of a group into its first row: slots are
      # added up and items are appended, keeping the quote style of every
      # moved scalar (e.g. `|-` descriptions).
      def merge_rows(group)
        grid_selector = "days[#{group[:day_index]}].grid"
        grid = document[grid_selector]
        first_index, *duplicate_indices = group[:row_indices]
        rows = group[:row_indices].map { |index| document.value_at("#{grid_selector}[#{index}]") }

        grid[first_index]["slots"] = rows.sum { |row| row_slots(row) }

        if items_row?(rows.first)
          items_selector = "#{grid_selector}[#{first_index}].items"
          offset = document.length_at(items_selector)

          moved = duplicate_indices.flat_map do |row_index|
            Array(rows[group[:row_indices].index(row_index)]["items"]).each_index.map do |item_index|
              "#{grid_selector}[#{row_index}].items[#{item_index}]"
            end
          end

          styles = moved.map { |selector| scalar_styles(selector) }

          document[items_selector].concat(moved.map { |selector| document.value_at(selector) })

          styles.each_with_index do |item_styles, index|
            item_styles.each do |suffix, style|
              document["#{items_selector}[#{offset + index}]#{suffix}"].quote_style = style
            end
          end
        end

        duplicate_indices.reverse_each { |index| grid.delete_at(index) }
      end

      # Quote styles of the scalars of an item, keyed by selector suffix.
      def scalar_styles(selector)
        value = document.value_at(selector)

        suffixes = value.is_a?(Hash) ? value.filter_map { |key, v| ".#{key}" if v.is_a?(String) } : [""]

        suffixes.to_h { |suffix| [suffix, document["#{selector}#{suffix}"].quote_style] }
      end

      def schedule
        @schedule ||= Static::Schedule.in_file(@file_path.to_s, document: @document).first
      end

      # Groups of duplicate rows, as hashes with the day index, the indices of
      # the rows sharing a time, and whether they can be merged automatically.
      def duplicate_groups
        return @duplicate_groups if defined?(@duplicate_groups)

        @duplicate_groups = []

        Array(schedule&.[]("days")).each_with_index do |day, day_index|
          grid = Array(day["grid"])

          grid.each_with_index
            .group_by { |row, _| [row["start_time"], row["end_time"], items_row?(row)] }
            .each_value do |entries|
              next if entries.size < 2

              row_indices = entries.map(&:last)

              @duplicate_groups << {
                day: day,
                day_index: day_index,
                row_indices: row_indices,
                mergeable: mergeable?(entries.map(&:first), row_indices)
              }
            end
        end

        @duplicate_groups
      end

      def mergeable?(rows, row_indices)
        adjacent = row_indices.each_cons(2).all? { |a, b| b == a + 1 }
        same_details = rows.map { |row| row.except(*MERGEABLE_KEYS) }.uniq.one?

        adjacent && same_details
      end

      def items_row?(row)
        Array(row["items"]).any?
      end

      def row_slots(row)
        (row["slots"] || Array(row["items"]).size).to_i
      end

      def source_location(day_index, row_index)
        schedule.source_location("days[#{day_index}].grid[#{row_index}]")
      end

      def error(group, row_index, first_line)
        row = group[:day]["grid"][row_index]
        day_label = group[:day]["name"] || group[:day]["date"]
        time = "#{row["start_time"]}-#{row["end_time"]}"
        location = source_location(group[:day_index], row_index)

        hint =
          if group[:mergeable]
            "Merge them into one row with a higher slot count. Run `bin/rails validate:fix` to merge them."
          else
            "Fix the time if it's a typo, or merge them into one row with a higher slot count."
          end

        Static::Validators::Error.new(
          %(slots at #{time} on "#{day_label}" repeat the start_time and end_time of the row on line #{first_line}. #{hint}),
          file_path: @file_path,
          line: location&.start_line || 1,
          end_line: location&.end_line
        )
      end
    end
  end
end
