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

        PATTERNS.any? { |pattern| File.fnmatch?(pattern, @file_path, File::FNM_PATHNAME | File::FNM_DOTMATCH) }
      end

      def errors
        @errors ||= validate
      end

      def validate
        return [] unless applicable?

        videos_file.pairs.flat_map do |video, talks|
          parent_id = video["id"]
          cued = (missing_thumbnail_error(video, video["id"], thumbnail_path(nil, video["id"])) if video["id"].present?)

          nested = talks.filter_map do |child|
            next if parent_id.blank? || child["video_id"].blank?

            missing_thumbnail_error(child, child["video_id"], thumbnail_path(parent_id, child["video_id"]))
          end

          [cued, *nested].compact
        end
      end

      def missing_thumbnail_error(talk, name, path)
        return unless speaker?(talk) && usable_start_cue?(talk)
        return if File.exist?(path)

        location = talk.source_location("video_id") || talk.source_location("start_cue")

        Static::Validators::Error.new(
          %(missing thumbnail for talk "#{name}" at #{relative_path(path)}. Run `bin/rails extract_thumbnails` to generate it.),
          file_path: @file_path,
          line: location&.start_line || 1,
          end_line: location&.end_line
        )
      end

      def videos_file
        @videos_file ||= Static::Talk.in_file(@file_path, document: @document)
      end

      private

      def speaker?(child)
        Array(child["speakers"]).any? { |name| name.to_s.strip.present? }
      end

      def usable_start_cue?(child)
        cue = child["start_cue"]
        cue.present? && cue != "TODO"
      end

      def thumbnail_path(parent_id, video_id)
        Rails.root.join(THUMBNAIL_ROOT, *[event_slug, parent_id, "#{video_id}.webp"].compact)
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
