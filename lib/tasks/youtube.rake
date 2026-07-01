# frozen_string_literal: true

namespace :youtube do
  require "gum"

  desc "Fetch and set published_at dates for YouTube videos missing them"
  task fetch_published_at: :environment do
    puts Gum.style("Fetching published_at dates from YouTube", border: "rounded", padding: "0 2", border_foreground: "5")
    puts

    missing = Static::VideosFile.youtube_videos_missing_published_at
    total = missing.size

    if total == 0
      puts Gum.style("✓ All YouTube videos have a published_at date", foreground: "2")
      next
    end

    puts "Found #{total} YouTube videos missing published_at"
    puts

    client = YouTube::Video.new
    updated_files = Set.new
    updated = 0
    errors = 0

    missing.each_slice(50).with_index do |batch, batch_index|
      video_ids = batch.map { |entry| entry["video_id"] }

      puts "Fetching batch #{batch_index + 1} (#{video_ids.size} videos)..."

      snippets = fetch_snippets(client, video_ids)

      batch.each do |entry|
        video_id = entry["video_id"]
        id = entry["id"]
        file = entry["__file"]

        snippet = snippets[video_id]

        unless snippet
          puts Gum.style("  ✗ #{id} (#{video_id}) — not found on YouTube", foreground: "1")
          errors += 1
          next
        end

        published_at = snippet["publishedAt"]&.to_date&.to_s

        unless published_at
          puts Gum.style("  ✗ #{id} (#{video_id}) — no publishedAt in response", foreground: "1")
          errors += 1
          next
        end

        videos_file = Static::VideosFile.new(file)
        node = videos_file.find_by(video_id: video_id)

        unless node
          puts Gum.style("  ✗ #{id} — could not find node in #{file}", foreground: "1")
          errors += 1
          next
        end

        if node.key?("published_at")
          node["published_at"] = published_at
        else
          node.insert("published_at", published_at, after: "date")
        end

        node["published_at"].quote_style = "double"

        updated_files << videos_file
        puts Gum.style("  ✓ #{id} → #{published_at}", foreground: "2")
        updated += 1
      end
    end

    updated_files.each(&:save!)

    puts
    if updated > 0
      puts Gum.style("Updated #{updated} videos", border: "rounded", padding: "0 2", foreground: "2", border_foreground: "2")
    end

    if errors > 0
      puts Gum.style("#{errors} errors", border: "rounded", padding: "0 2", foreground: "1", border_foreground: "1")
    end
  end

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
      puts Gum.style("Run: rails youtube:fetch_published_at", foreground: "3")
    end
  end

  desc "Sync published_at for YouTube videos against the API (fills missing and corrects mismatches). DRY_RUN=1 to preview."
  task sync_published_at: :environment do
    dry_run = ENV["DRY_RUN"].present?
    min_drift = Integer(ENV.fetch("MIN_DRIFT_DAYS", "1"))  # ignore ±N days as timezone noise (local date vs API UTC date)
    max_drift = Integer(ENV.fetch("MAX_DRIFT_DAYS", "365")) # skip API dates far later than stored (likely re-uploads)

    parse_date = ->(value) do
      Date.parse(value.to_s)
    rescue Date::Error, TypeError
      nil
    end

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

    puts Gum.style("Auditing #{entries.size} YouTube videos against the API", border: "rounded", padding: "0 2", border_foreground: "5")
    api = YouTube::Video.new.get_published_at(entries.map { |e| e[:video_id] }.uniq)

    stats = Hash.new(0)
    writes = []
    skipped = []

    entries.each do |entry|
      api_date = api[entry[:video_id]]&.to_date
      stored_date = parse_date.call(entry[:stored])

      status =
        if api_date.nil? then :api_missing
        elsif entry[:stored].empty? then :stored_blank
        elsif stored_date.nil? then :stored_unparseable
        elsif stored_date == api_date then :match
        else :mismatch
        end

      stats[status] += 1

      next if status == :match || status == :api_missing

      drift = stored_date ? (api_date - stored_date).to_i : nil

      if max_drift.positive? && drift && drift > max_drift
        skipped << entry.merge(api_date:, drift:)

        next
      end

      next if drift && drift.abs <= min_drift

      writes << entry.merge(api_date:, status:, drift:)
    end

    puts %i[match mismatch stored_blank stored_unparseable api_missing].each { |k| puts "  #{k.to_s.ljust(20)} #{stats[k]}" }
    puts Gum.style("  #{"to write".ljust(20)} #{writes.size}", foreground: "2")
    puts Gum.style("  #{"skipped re-uploads".ljust(20)} #{skipped.size}", foreground: "3") if skipped.any?

    if writes.empty?
      puts
      puts Gum.style("✓ Nothing to sync", foreground: "2")
      next
    end

    puts

    writes.first(40).each do |w|
      puts Gum.style("  #{"[dry-run] " if dry_run}#{(w[:stored].empty? ? "(blank)" : w[:stored]).ljust(12)} → #{w[:api_date]}  #{w[:video_id]}", foreground: "2")
    end

    puts "  ... and #{writes.size - 40} more" if writes.size > 40

    if dry_run
      puts
      puts Gum.style("Dry run — re-run without DRY_RUN=1 to apply", foreground: "3")
      next
    end

    writes.each do |write|
      node = write[:node]
      value = write[:api_date].iso8601

      if node.key?("published_at")
        node["published_at"] = value
      else
        node.insert("published_at", value, after: "date")
      end

      node["published_at"].quote_style = "double"
    end

    writes.map { |w| w[:file] }.uniq.each(&:save!)

    puts
    puts Gum.style("Updated #{writes.size} videos", border: "rounded", padding: "0 2", foreground: "2", border_foreground: "2")
  end

  private

  def fetch_snippets(client, video_ids)
    path = "/videos"

    query = {
      part: "snippet",
      id: video_ids.join(",")
    }

    response = client.send(:all_items, path, query: query)

    response.each_with_object({}) do |item, hash|
      hash[item["id"]] = item["snippet"]
    end
  end
end
