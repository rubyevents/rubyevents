# frozen_string_literal: true

module Static
  module Validators
    class MeetupEventSlug
      include GitBaseline

      PATTERNS = [
        "**/event.yml"
      ].freeze

      SUFFIXES = %w[-meetup -brigade -group -usergroup].freeze

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

        location = event.source_location("id")
        rule = %(Meetup event ids end in "-meetup", "-brigade", "-group", "-usergroup" or a Ruby User Group abbreviation like "rughh")
        message = if !expected
          %(id "#{slug}" has "meetup" in the middle. #{rule}, rename it by hand.)
        elsif published?
          %(id "#{slug}" should be "#{expected}". #{rule}. This event is already on main, so renaming it needs the production event migrated as well.)
        else
          %(id "#{slug}" should be "#{expected}". #{rule}. Run `bin/rails validate:fix` to rename it.)
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
        return unless mismatched? && expected && !published?

        event.rename!(expected)

        {changed: 1, file_path: @file_path}
      end

      private

      def event
        @event ||= Static::Event.in_file(@file_path.to_s, document: @document).first
      end

      def slug
        event["id"].to_s
      end

      def expected
        "#{slug}-meetup" unless slug.match?(/(?:\A|-)meetup(?:-|\z)/)
      end

      def mismatched?
        applicable? && event&.meetup? && !MeetupNaming.ignored?(event) && !slug.end_with?(*SUFFIXES) && !user_group_abbreviation?
      end

      # "rughh", "lrug" or "nwrug": RUG stands for Ruby User Group.
      def user_group_abbreviation?
        slug.split("-").last.include?("rug")
      end

      def published?
        !baseline.nil?
      end
    end
  end
end
