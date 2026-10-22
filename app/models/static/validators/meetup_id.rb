# frozen_string_literal: true

module Static
  module Validators
    class MeetupId
      include GitBaseline

      PATTERNS = [
        "**/videos.yml"
      ].freeze

      def initialize(file_path:, document: nil, baseline: nil)
        @file_path = file_path
        @document = document
        @baseline = baseline
      end

      def applicable?
        return false unless File.exist?(@file_path)

        matches = PATTERNS.any? do |pattern|
          File.fnmatch?(pattern, @file_path, File::FNM_PATHNAME | File::FNM_DOTMATCH)
        end

        matches && meetup_event?
      end

      def errors
        @errors ||= validate
      end

      def validate
        return [] unless applicable?

        map_unexpected_ids do |node, expected|
          actual = node["id"].to_s
          location = node.source_location("id")

          Static::Validators::Error.new(
            %(id "#{actual}" does not match the expected id "#{expected}". Meetup ids should be "#{event_slug}-<month>-<year>", with the day added when a month has more than one meetup ("#{event_slug}-<day>-<month>-<year>") and a counter for meetups on the same day. Run `bin/rails validate:fix` to rename it and keep the current id as old_id.),
            file_path: @file_path,
            line: location&.start_line || 1,
            end_line: location&.end_line
          )
        end.compact
      end

      def fix
        return unless applicable?

        changes = map_unexpected_ids do |node, expected|
          current = node["id"].to_s
          node["old_id"] = current if node["old_id"].blank? && id_in_baseline?(current)
          node.delete("old_id") if node["old_id"] == expected
          if node["video_id"] == current && !watchable_video?(node)
            node["video_id"] = expected
          end
          node["id"] = expected
        end.compact
        return unless changes.any?
        videos_file.save!
        {changed: changes.size, file_path: @file_path}
      end

      private

      def map_unexpected_ids
        expected_ids.map do |node, expected|
          actual = node["id"].to_s
          yield(node, expected) if actual != expected
        end
      end

      # Editions are grouped by month; a month with several editions gets the day in
      # every id, and editions on the same day are numbered in file order.
      def expected_ids
        @expected_ids ||= editions.group_by { |node| date_for(node).strftime("%Y-%m") }.each_with_object({}) do |(_month, month_group), result|
          month_group.group_by { |node| date_for(node) }.each do |date, day_group|
            base = month_group.one? ? "#{event_slug}-#{month_slug(date)}" : "#{event_slug}-#{date.strftime("%d")}-#{month_slug(date)}"

            day_group.each_with_index do |node, index|
              result[node] = index.zero? ? base : "#{base}-#{index + 1}"
            end
          end
        end
      end

      def editions
        @editions ||= nodes.select { |node| node.parent.nil? && date_for(node) }
      end

      def date_for(node)
        @dates ||= {}
        return @dates[node] if @dates.key?(node)

        @dates[node] = begin
          Date.iso8601(node["date"].to_s)
        rescue Date::Error
          nil
        end
      end

      def month_slug(date)
        "#{date.strftime("%B").downcase}-#{date.year}"
      end

      def nodes
        @nodes ||= videos_file.to_a
      end

      def videos_file
        @videos_file ||= Static::Talk.in_file(@file_path, document: @document)
      end

      def event_slug
        @event_slug ||= File.basename(File.dirname(File.expand_path(@file_path)))
      end

      def meetup_event?
        nodes.first&.event&.[]("kind") == "meetup"
      end

      def watchable_video?(node)
        node["video_provider"].in?(::Talk::WATCHABLE_PROVIDERS)
      end

      def id_in_baseline?(id)
        baseline_ids.include?(id)
      end

      def baseline_ids
        @baseline_ids ||= baseline ? baseline.ids : []
      end

      def baseline
        @baseline ||= begin
          document = self.class.baseline_file(relative_path)
          Static::Talk.in_file(relative_path, document: document) if document
        end
      end
    end
  end
end
