# frozen_string_literal: true

require "open3"

module Static
  class VideosFile
    VIDEOS_GLOB = "data/**/videos.yml"

    attr_reader :path, :document

    def initialize(path, document: nil)
      @path = path
      @document = document || Yerba.parse_file(path)
    end

    def self.parse(content, path: nil)
      new(path, document: Yerba.parse(content))
    end

    def self.from(path)
      new(Rails.root.join(path.to_s).to_s)
    end

    def self.all
      @all ||= Dir.glob(Rails.root.join(VIDEOS_GLOB)).filter_map do |path|
        new(path)
      rescue Errno::ENOENT
        nil
      end
    end

    def self.clear_cache!
      @all = nil
    end

    def self.each_video(&block)
      all.each do |file|
        file.each_video(&block)
      end
    end

    def self.each_talk(&block)
      all.each do |file|
        file.each_talk(&block)
      end
    end

    def self.find_by_video_id(video_id)
      each_video do |video, file|
        return [video, file] if video.value_at("video_id") == video_id
      end

      each_talk do |talk, _video, file|
        return [talk, file] if talk.value_at("video_id") == video_id
      end

      nil
    end

    def self.find_by_id(id)
      each_video do |video, file|
        return [video, file] if video.value_at("id") == id
      end

      each_talk do |talk, _video, file|
        return [talk, file] if talk.value_at("id") == id
      end

      nil
    end

    def self.added_videos(since)
      all.flat_map { |file| file.added_videos(since) }
    end

    def self.newly_watchable_videos(since)
      all.flat_map { |file| file.newly_watchable_videos(since) }
    end

    def self.youtube_videos_missing_published_at
      glob = Rails.root.join(VIDEOS_GLOB).to_s

      top_level = Yerba::Collection.find(glob, "[]", condition: ".video_provider == youtube")
      talks = Yerba::Collection.find(glob, "[].talks[]", condition: ".video_provider == youtube")

      (Array(top_level) + Array(talks)).select do |entry|
        published_at = entry["published_at"]
        published_at.nil? || published_at.to_s.strip.empty? || published_at == "TODO"
      end
    end

    def count
      document.root.length
    end
    alias_method :length, :count

    def find_by(id: nil, video_id: nil)
      field = id ? :id : :video_id
      value = id || video_id

      document.find_by(field => value) ||
        document.root.each.filter_map { |v| v["talks"]&.find_by(field => value) }.first
    end

    def talks
      top_level_talks + sub_talks
    end

    def ids
      talks.filter_map { |talk| talk.value_at("id") }
    end

    def old_ids
      talks.filter_map { |talk| talk.value_at("old_id") }
    end

    def top_level_talks
      sequence_items(document.root)
    end

    def sub_talks
      top_level_talks.flat_map do |video|
        talks = video["talks"]
        next [] unless talks

        talks.each.to_a
      end
    end

    def each_video(&block)
      top_level_talks.each do |video|
        yield video, self
      end
    end

    def each_talk(&block)
      top_level_talks.each do |video|
        talks = video["talks"]
        next unless talks

        talks.each do |talk|
          yield talk, video, self
        end
      end
    end

    def save!
      document.save!(apply: true)
    end

    def changed?
      document.changed?
    end

    def relative_path
      path.sub("#{Rails.root}/", "")
    end

    def at(timestamp)
      return nil if path.blank?

      revision, _, status = git("rev-list", "--max-count=1", "--before", timestamp.to_time.iso8601, "HEAD", "--", File.basename(path.to_s))
      return nil unless status.success? && revision.strip.present?

      content, _, status = git("show", "#{revision.strip}:./#{File.basename(path.to_s)}")
      return nil unless status.success?

      self.class.parse(content, path: path)
    end

    def changes(since)
      snapshot = at(since)
      return nil unless snapshot

      current = talks_by_id
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

    def added_videos(since)
      diff = changes(since)

      diff ? diff[:added] : ids
    end

    def newly_watchable_videos(since)
      diff = changes(since)
      return [] unless diff

      diff[:modified].filter_map { |id, attributes|
        next unless attributes.key?("video_provider")

        before, after = attributes["video_provider"]

        id if !watchable_provider?(before) && watchable_provider?(after)
      }
    end

    protected

    def talks_by_id
      talks.index_by { |talk| talk.value_at("id") }.except(nil)
    end

    private

    def watchable_provider?(provider)
      (provider || "youtube").in?(Talk::WATCHABLE_PROVIDERS)
    end

    def attribute_changes(before, after)
      (before.keys | after.keys).filter_map do |key|
        next if key == "talks"

        [key, [before[key], after[key]]] if before[key] != after[key]
      end.to_h
    end

    def git(*args)
      Open3.capture3("git", "-C", File.dirname(path.to_s), *args)
    end

    def sequence_items(node)
      node.is_a?(Yerba::Sequence) ? node.each.to_a : []
    end
  end
end
