# frozen_string_literal: true

module Static
  module Validators
    class MeetupEventTitle
      PATTERNS = [
        "**/event.yml"
      ].freeze

      SUFFIX = /(?:\s+Meetup)+\z/i
      GROUP_SUFFIX = /\s(?:Brigade|Group|Usergroup)\z/i

      # The title a meetup event should have, or nil when "Meetup" appears in the middle
      # of the title ("Ruby Meetup Oslo") and only a human can tell what it should be.
      # Groups that call themselves a Brigade or (User) Group keep that name.
      def self.expected_title(title)
        name = title.to_s.strip.sub(SUFFIX, "")
        return name if name.match?(GROUP_SUFFIX) && !title.to_s.strip.match?(SUFFIX)
        return if name.match?(/\bMeetup\b/i)

        "#{name} Meetup"
      end

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
        return [] unless mismatched?

        location = event.source_location("title")
        message = if expected
          %(title "#{title}" should be "#{expected}". Meetup events are titled "<name> Meetup", or end in Brigade, Group or Usergroup. Run `bin/rails validate:fix` to update it.)
        else
          %(title "#{title}" has "Meetup" in the middle. Meetup events are titled "<name> Meetup", or end in Brigade, Group or Usergroup, rename it by hand.)
        end

        [
          Static::Validators::Error.new(
            message,
            file_path: @file_path,
            line: location&.start_line || 1,
            end_line: location&.end_line
          )
        ]
      end

      def fix
        return unless mismatched? && expected

        event["title"] = expected
        event.save!

        {changed: 1, file_path: @file_path}
      end

      private

      def event
        @event ||= Static::Event.in_file(@file_path.to_s, document: @document).first
      end

      def title
        event["title"].to_s
      end

      def expected
        self.class.expected_title(title)
      end

      def mismatched?
        applicable? && event&.meetup? && !MeetupNaming.ignored?(event) && title != expected
      end
    end
  end
end
