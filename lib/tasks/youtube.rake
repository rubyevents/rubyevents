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
