# frozen_string_literal: true

namespace :youtube do
  require "gum"

  desc "List YouTube videos missing published_at"
  task missing_published_at: :environment do
    missing = Static::VideosFile.youtube_videos_missing_published_at

    if missing.empty?
      puts Gum.style("✓ All YouTube videos have a published_at date", foreground: "2")
    else
      puts Gum.style("YouTube videos missing published_at (#{missing.size}):", foreground: "1")
      puts

      missing.each do |entry|
        file = entry["__file"].sub("#{Rails.root}/", "")
        puts Gum.style("  ❌ #{entry["id"]} (#{entry["video_id"]}) in #{file}", foreground: "1")
      end

      puts
      puts Gum.style("Run: rails youtube:sync_published_at", foreground: "3")
    end
  end

  desc "Set published_at (UTC datetime) for YouTube videos that are missing/blank, from the API. Requires a YouTube API key. DRY_RUN=1 to preview."
  task sync_published_at: :environment do
    sync_youtube_published_at(only_missing: true)
  end

  namespace :sync_published_at do
    desc "Sync published_at (UTC datetime) for ALL YouTube videos against the API. Requires a YouTube API key. DRY_RUN=1 to preview."
    task all: :environment do
      sync_youtube_published_at(only_missing: false)
    end
  end

  private

  def sync_youtube_published_at(only_missing:)
    return unless youtube_api_key_present!

    dry_run = ENV["DRY_RUN"].present?

    parse_date = ->(value) do
      Date.parse(value.to_s)
    rescue Date::Error, TypeError
      nil
    end

    missing = ->(stored) { stored.empty? || stored == "TODO" }

    entries = []

    Static::VideosFile.all.each do |file|
      file.each_video do |video, _|
        next unless video.value_at("video_provider") == "youtube"

        entries << {file:, node: video, video_id: video.value_at("video_id").to_s, stored: video.value_at("published_at").to_s.strip}
      end

      file.each_talk do |talk, _video, _|
        next unless talk.value_at("video_provider") == "youtube"

        entries << {file:, node: talk, video_id: talk.value_at("video_id").to_s, stored: talk.value_at("published_at").to_s.strip}
      end
    end

    entries.reject! { |e| e[:video_id].empty? }
    entries.select! { |e| missing.call(e[:stored]) } if only_missing

    scope = only_missing ? "missing/blank" : "all"
    puts Gum.style("Auditing #{entries.size} YouTube videos (#{scope}) against the API", border: "rounded", padding: "0 2", border_foreground: "5")
    api = YouTube::Video.new.get_published_at(entries.map { |e| e[:video_id] }.uniq)

    midnight_utc = ->(date) { Time.utc(date.year, date.month, date.day).iso8601 }

    stats = Hash.new(0)
    writes = []

    entries.each do |entry|
      api_time = api[entry[:video_id]]
      stored_date = parse_date.call(entry[:stored])

      desired =
        if api_time
          api_time.utc.iso8601
        elsif stored_date
          midnight_utc.call(stored_date)
        end

      if desired.nil?
        stats[:unresolved] += 1
        next
      elsif entry[:stored] == desired
        stats[:match] += 1
        next
      end

      stats[missing.call(entry[:stored]) ? :blank : :corrected] += 1
      writes << entry.merge(desired:)
    end

    %i[match corrected blank unresolved].each { |k| puts "  #{k.to_s.ljust(20)} #{stats[k]}" }
    puts Gum.style("  #{"to write".ljust(20)} #{writes.size}", foreground: "2")

    if writes.empty?
      puts
      puts Gum.style("✓ Nothing to sync", foreground: "2")
      return
    end

    puts

    writes.first(40).each do |w|
      puts Gum.style("  #{"[dry-run] " if dry_run}#{(w[:stored].empty? ? "(blank)" : w[:stored]).ljust(20)} → #{w[:desired]}  #{w[:video_id]}", foreground: "2")
    end

    puts "  ... and #{writes.size - 40} more" if writes.size > 40

    if dry_run
      puts
      puts Gum.style("Dry run — re-run without DRY_RUN=1 to apply", foreground: "3")
      return
    end

    writes.each do |write|
      node = write[:node]

      if node.key?("published_at")
        node["published_at"] = write[:desired]
      else
        node.insert("published_at", write[:desired], after: "date")
      end

      node["published_at"].quote_style = "double"
    end

    writes.map { |w| w[:file] }.uniq.each(&:save!)

    puts
    puts Gum.style("Updated #{writes.size} videos", border: "rounded", padding: "0 2", foreground: "2", border_foreground: "2")
  end

  def youtube_api_key_present!
    return true if Rails.application.credentials.youtube&.dig(:api_key).present? || ENV["YOUTUBE_API_KEY"].present?

    puts Gum.style("A YouTube API key is required for this task.", foreground: "1", border: "rounded", padding: "0 2", border_foreground: "1")
    puts Gum.style("Set credentials.youtube.api_key or the YOUTUBE_API_KEY environment variable.", foreground: "3")

    false
  end
end
