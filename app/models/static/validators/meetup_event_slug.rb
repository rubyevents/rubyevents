# frozen_string_literal: true

module Static
  module Validators
    class MeetupEventSlug
      include GitBaseline

      PATTERNS = [
        "**/event.yml"
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
        return [] unless mismatched?

        location = event.source_location("id")
        message = if !expected
          %(id "#{slug}" has "meetup" in the middle. Meetup event ids end in "-meetup", rename it by hand.)
        elsif published?
          %(id "#{slug}" should be "#{expected}". Meetup event ids end in "-meetup". This event is already on main, so renaming it needs the production event migrated as well.)
        else
          %(id "#{slug}" should be "#{expected}". Meetup event ids end in "-meetup". Run `bin/rails validate:fix` to rename it.)
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
        applicable? && event&.meetup? && !slug.end_with?("-meetup")
      end

      def published?
        !baseline.nil?
      end
    end
  end
end
