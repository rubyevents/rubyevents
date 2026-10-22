# frozen_string_literal: true

module Static
  module Validators
    class MeetupEditionTitle
      PATTERNS = [
        "**/videos.yml"
      ].freeze

      MONTH_YEAR = /\s+((?:#{Date::MONTHNAMES.compact.join("|")}) \d{4})\z/

      def initialize(file_path:, document: nil)
        @file_path = file_path
        @document = document
      end

      def applicable?
        return false unless File.exist?(@file_path)

        matches = PATTERNS.any? do |pattern|
          File.fnmatch?(pattern, @file_path, File::FNM_PATHNAME | File::FNM_DOTMATCH)
        end

        matches && event&.meetup?
      end

      def errors
        @errors ||= validate
      end

      def validate
        renames.map do |node, expected|
          location = node.source_location("title")

          Static::Validators::Error.new(
            %(title "#{node["title"]}" should be "#{expected}". Meetup editions are titled "#{event_title} <Month> <Year>". Run `bin/rails validate:fix` to update it.),
            file_path: @file_path,
            line: location&.start_line || 1,
            end_line: location&.end_line
          )
        end
      end

      def fix
        changes = renames
        return if changes.empty?

        changes.each do |node, expected|
          current = node["title"]

          node["title"] = expected
          node["event_name"] = expected if node["event_name"] == current

          node.talks.each do |talk|
            talk["event_name"] = expected if talk["event_name"] == current
          end
        end

        videos_file.save!

        {changed: changes.size, file_path: @file_path}
      end

      private

      def renames
        return [] unless applicable? && event_title

        editions.filter_map do |node|
          title = node["title"].to_s
          month_year = title[MONTH_YEAR, 1]
          next unless month_year

          name = title.delete_suffix(" #{month_year}")
          next unless name.in?(outdated_names)

          [node, "#{event_title} #{month_year}"]
        end
      end

      def outdated_names
        @outdated_names ||= [event["title"].to_s, event_title.delete_suffix(" Meetup")].uniq - [event_title]
      end

      def event_title
        @event_title ||= Static::Validators::MeetupEventTitle.expected_title(event["title"])
      end

      def editions
        @editions ||= videos_file.to_a.select { |node| node.parent.nil? }
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
