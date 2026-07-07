# frozen_string_literal: true

module Static
  module Validators
    class RedundantThumbnails
      PATTERNS = ["**/thumbnails/**/*.webp"].freeze
      REMOTE_THUMBNAIL_PROVIDERS = %w[youtube vimeo].freeze

      def initialize(file_path:, document: nil)
        @file_path = file_path.to_s
      end

      def applicable?
        return false unless File.exist?(@file_path)

        PATTERNS.any? do |pattern|
          File.fnmatch?(pattern, @file_path, File::FNM_PATHNAME)
        end
      end

      def errors
        @errors ||= validate
      end

      def validate
        return [] unless applicable?

        video_id = File.basename(@file_path, ".webp")
        entry = self.class.talk_lookup[video_id]

        if entry.nil?
          return [error("no talk with video_id '#{video_id}' exists, this file can be deleted")]
        end

        talk = entry[:talk]
        expected_directory = File.join(*[entry[:event_slug], entry[:parent_id]].compact)

        if directory != expected_directory
          return [error("talk '#{video_id}' belongs to '#{expected_directory}', move this file to thumbnails/#{expected_directory}/#{video_id}.webp")]
        end

        return [] if usable_start_cue?(talk)

        provider = talk["video_provider"]
        return [] unless REMOTE_THUMBNAIL_PROVIDERS.include?(provider)

        [error("talk '#{video_id}' has no start_cue and its #{provider} thumbnail is available remotely, this file can be deleted")]
      end

      def self.talk_lookup
        @talk_lookup ||= Static::Video.all.each_with_object({}) do |video, lookup|
          event_slug = File.basename(File.dirname(video.__file_path.to_s))

          register = lambda do |talk, parent_id|
            [talk.id, talk.video_id].compact.each do |key|
              lookup[key] ||= {talk: talk, event_slug: event_slug, parent_id: parent_id}
            end
          end

          register.call(video, nil)
          video.talks.each { |talk| register.call(talk, video.id) }
        end
      end

      def self.warmup
        talk_lookup
      end

      def self.reset!
        @talk_lookup = nil
      end

      private

      def directory
        File.dirname(@file_path.split("thumbnails/").last)
      end

      def usable_start_cue?(talk)
        cue = talk.start_cue
        cue.present? && cue != "TODO"
      end

      def error(message)
        Static::Validators::Error.new(
          "Redundant thumbnail: #{message}",
          file_path: @file_path,
          line: 1
        )
      end
    end
  end
end
