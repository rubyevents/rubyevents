# frozen_string_literal: true

module Speakerdeck
  class SlidesScanner
    VIDEOS_GLOB = "data/**/videos.yml"
    VIDEO_SELECTORS = ["[]", "[].talks[]"].freeze

    IGNORED_HANDLES = [
      "andpad",
      "coincheck_recruit",
      "guru_sp",
      "gurzu",
      "linkers_tech",
      "plataformatec",
      "techouse"
    ].freeze

    PROBLEMATIC_PATTERNS = [
      {pattern: %r{speakerdeck\.com/player/}, label: "player URL (needs user/slug URL)"},
      {pattern: %r{speakerdeck\.com/u/}, label: "legacy /u/ URL (migrate to /user/slug)"}
    ].freeze

    attr_reader :handles_by_speaker, :urls_by_speaker

    def initialize
      @handles_by_speaker = Hash.new { |h, k| h[k] = Set.new }
      @urls_by_speaker = Hash.new { |h, k| h[k] = [] }
    end

    def scan
      each_speakerdeck_entry(select: "slides_url,speakers") do |entry|
        process_entry(entry)
      end

      self
    end

    def candidates
      handles_by_speaker.select { |_, handles| handles.size == 1 }
    end

    def multi_handle_speakers
      handles_by_speaker
        .transform_values { |handles| handles - IGNORED_HANDLES }
        .select { |_, handles| handles.size > 1 }
    end

    def problematic_urls
      issues = []

      each_speakerdeck_entry(select: "slides_url") do |entry|
        url = entry["slides_url"].to_s
        relative = entry["__file"].to_s.sub("#{Rails.root}/data/", "")

        PROBLEMATIC_PATTERNS.each do |check|
          if url.match?(check[:pattern])
            issues << {path: relative, url: url, label: check[:label]}
          end
        end
      end

      issues
    end

    private

    def each_speakerdeck_entry(select:, &block)
      glob = Rails.root.join(VIDEOS_GLOB).to_s

      VIDEO_SELECTORS.each do |selector|
        results = Yerba::Collection.find(glob, selector, condition: ".slides_url contains speakerdeck", select: select)

        Array(results).each(&block)
      end
    end

    def process_entry(entry)
      url = entry["slides_url"].to_s
      relative = entry["__file"].to_s.sub("#{Rails.root}/", "")

      match = url.match(%r{speakerdeck\.com/(?:u/)?([^/]+)/})
      return unless match

      handle = match[1]
      return if handle.blank?
      return if IGNORED_HANDLES.include?(handle)

      speakers = Array(entry["speakers"])
      return unless speakers.size == 1

      name = speakers.first

      handles_by_speaker[name] << handle
      urls_by_speaker[name] << "#{relative}: #{url}"
    end
  end
end
