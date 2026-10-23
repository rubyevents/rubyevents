# frozen_string_literal: true

module Static
  module Validators
    class MeetupEditionProvider
      PATTERNS = [
        "**/videos.yml"
      ].freeze

      def initialize(file_path:, document: nil)
        @file_path = file_path
        @document = document
      end

      def applicable?
        return false unless File.exist?(@file_path)

        matches = PATTERNS.any? do |pattern|
          File.fnmatch?(pattern, @file_path, File::FNM_PATHNAME | File::FNM_DOTMATCH)
        end

        matches && event&.meetup? && !MeetupNaming.ignored?(event)
      end

      def errors
        @errors ||= validate
      end

      def validate
        mismatched_editions.map do |edition|
          location = edition.source_location("video_provider")

          Static::Validators::Error.new(
            %(video_provider "#{edition["video_provider"]}" of meetup edition "#{edition["id"]}" should be "children". Meetup editions list their talks in `talks`, only an edition with its own recording uses #{::Talk::WATCHABLE_PROVIDERS.join(", ")}. Run `bin/rails validate:fix` to update it.),
            file_path: @file_path,
            line: location&.start_line || 1,
            end_line: location&.end_line
          )
        end
      end

      def fix
        editions = mismatched_editions
        return if editions.empty?

        editions.each { |edition| edition["video_provider"] = "children" }
        videos_file.save!

        {changed: editions.size, file_path: @file_path}
      end

      private

      def mismatched_editions
        return [] unless applicable?

        videos_file.to_a.select do |node|
          provider = node["video_provider"].to_s

          node.parent.nil? && provider != "children" && !provider.in?(::Talk::WATCHABLE_PROVIDERS)
        end
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
