# frozen_string_literal: true

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
      return [] unless document.root

      document.root.each.to_a
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
  end
end
