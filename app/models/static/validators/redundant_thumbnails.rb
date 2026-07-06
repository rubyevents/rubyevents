# frozen_string_literal: true

module Static
  module Validators
    class RedundantThumbnails
      PATTERNS = ["**/thumbnails/*.webp"].freeze
      REMOTE_THUMBNAIL_PROVIDERS = %w[youtube vimeo].freeze

      def initialize(file_path:)
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
        talk = self.class.talk_lookup[video_id]

        if talk.nil?
          return [error("no talk with video_id '#{video_id}' exists, this file can be deleted")]
        end

        return [] if usable_start_cue?(talk)

        provider = talk["video_provider"]
        return [] unless REMOTE_THUMBNAIL_PROVIDERS.include?(provider)

        [error("talk '#{video_id}' has no start_cue and its #{provider} thumbnail is available remotely, this file can be deleted")]
      end

      def self.talk_lookup
        @talk_lookup ||= Static::Video.all_talks.each_with_object({}) do |talk, lookup|
          [talk.id, talk.video_id].compact.each do |key|
            lookup[key] ||= talk
          end
        end
      end

      def self.reset!
        @talk_lookup = nil
      end

      private

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
