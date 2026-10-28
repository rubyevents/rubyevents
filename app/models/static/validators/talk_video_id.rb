# frozen_string_literal: true

module Static
  module Validators
    # A talk without a recording has no video of its own to point at, so its `video_id` is its own `id`.
    #
    class TalkVideoId
      PATTERNS = [
        "**/videos.yml"
      ].freeze

      PROVIDERS_WITHOUT_RECORDING = %w[not_recorded not_published scheduled].freeze

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

        mismatched.map do |node|
          location = node.source_location("video_id") || node.source_location("id")

          Static::Validators::Error.new(
            %(video_id "#{node["video_id"]}" should be "#{node["id"]}". A #{node["video_provider"]} talk uses its own id as its video_id. Run `bin/rails validate:fix` to update it.),
            file_path: @file_path,
            line: location&.start_line || 1,
            end_line: location&.end_line
          )
        end
      end

      def fix
        return unless applicable?

        nodes = mismatched
        return if nodes.empty?

        nodes.each { |node| node["video_id"] = node["id"] }
        videos_file.save!

        {changed: nodes.size, file_path: @file_path}
      end

      private

      def mismatched
        videos_file.pairs.flat_map { |video, nested| [video, *nested] }.select do |node|
          node["video_provider"].in?(PROVIDERS_WITHOUT_RECORDING) && node["id"].present? && node["video_id"] != node["id"]
        end
      end

      def videos_file
        @videos_file ||= Static::Talk.in_file(@file_path, document: @document)
      end
    end
  end
end
