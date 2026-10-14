# frozen_string_literal: true

require "open3"

module Static
  class Talk
    class History
      attr_reader :path

      def self.added_talks(since)
        Static::Talk.all.files.flat_map { |file| new(file.path).added_talks(since) }
      end

      def self.newly_watchable_talks(since)
        Static::Talk.all.files.flat_map { |file| new(file.path).newly_watchable_talks(since) }
      end

      def initialize(path)
        @path = path.to_s
      end

      def at(timestamp)
        return nil if path.blank?

        revision, _, status = git("rev-list", "--max-count=1", "--before", timestamp.to_time.iso8601, "HEAD", "--", File.basename(path))
        return nil unless status.success? && revision.strip.present?

        content, _, status = git("show", "#{revision.strip}:./#{File.basename(path)}")
        return nil unless status.success?

        Static::Talk.parse(content, path: path)
      end

      def changes(since)
        snapshot = at(since)
        return nil unless snapshot

        current = Static::Talk.in_file(path).talks_by_id
        previous = snapshot.talks_by_id

        modified = (current.keys & previous.keys).filter_map { |id|
          diff = attribute_changes(previous[id].to_h, current[id].to_h)

          [id, diff] if diff.any?
        }.to_h

        {
          added: current.keys - previous.keys,
          removed: previous.keys - current.keys,
          modified: modified
        }
      end

      def added_talks(since)
        diff = changes(since)

        diff ? diff[:added] : Static::Talk.in_file(path).ids
      end

      def newly_watchable_talks(since)
        diff = changes(since)
        return [] unless diff

        diff[:modified].filter_map { |id, attributes|
          next unless attributes.key?("video_provider")

          before, after = attributes["video_provider"]

          id if !watchable_provider?(before) && watchable_provider?(after)
        }
      end

      private

      def watchable_provider?(provider)
        (provider || "youtube").in?(::Talk::WATCHABLE_PROVIDERS)
      end

      def attribute_changes(before, after)
        (before.keys | after.keys).filter_map do |key|
          next if key == "talks"

          [key, [before[key], after[key]]] if before[key] != after[key]
        end.to_h
      end

      def git(*args)
        Open3.capture3("git", "-C", File.dirname(path), *args)
      end
    end
  end
end
