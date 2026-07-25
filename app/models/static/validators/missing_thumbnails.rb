# frozen_string_literal: true

module Static
  module Validators
    class MissingThumbnails
      PATTERNS = ["**/videos.yml"].freeze
      THUMBNAIL_ROOT = "app/assets/images/thumbnails"

      def initialize(file_path:, document: nil)
        @file_path = file_path
        @document = document
      end

      def applicable?
        return false unless File.exist?(@file_path)

        PATTERNS.any? { |pattern| File.fnmatch?(pattern, @file_path, File::FNM_PATHNAME) }
      end

      def errors
        @errors ||= validate
      end

      def validate
        return [] unless applicable?
        return [] unless document.root

        document.root.each.flat_map do |video|
          parent_id = video.value_at("id")

          Array(video["talks"]&.each&.to_a).filter_map do |child|
            next unless speaker?(child)
            next unless usable_start_cue?(child)

            video_id = child.value_at("video_id")
            next if parent_id.blank? || video_id.blank?

            path = thumbnail_path(parent_id, video_id)
            next if File.exist?(path)

            node = child["video_id"] || child["start_cue"]

            Static::Validators::Error.new(
              %(missing thumbnail for talk "#{video_id}" at #{relative_path(path)}. Run `bin/rails extract_thumbnails` to generate it.),
              file_path: @file_path,
              line: node&.location&.start_line || 1,
              end_line: node&.location&.end_line
            )
          end
        end
      end

      def document
        @document ||= Yerba.parse_file(@file_path)
      end

      private

      def speaker?(child)
        Array(child.value_at("speakers")).any? { |name| name.to_s.strip.present? }
      end

      def usable_start_cue?(child)
        cue = child.value_at("start_cue")
        cue.present? && cue != "TODO"
      end

      def thumbnail_path(parent_id, video_id)
        Rails.root.join(THUMBNAIL_ROOT, event_slug, parent_id, "#{video_id}.webp")
      end

      def event_slug
        @event_slug ||= File.basename(File.dirname(File.expand_path(@file_path)))
      end

      def relative_path(path)
        path.to_s.sub("#{Rails.root}/", "")
      end
    end
  end
end
