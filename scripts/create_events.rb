# start this script with the rails runner command
# $ rails runner scripts/create_events.rb
#
# This script fetches YouTube playlists for each series and creates event.yml files.
# You can optionally pass a series slug to only process that series:
#   rails runner scripts/create_events.rb railsconf

def create_events_for_series(series_file_path)
  series_slug = File.basename(File.dirname(series_file_path))
  series_data = YAML.load_file(series_file_path)

  return if series_data["youtube_channel_id"].blank?

  puts "Processing: #{series_slug}"

  playlists = YouTube::Playlists.new.all(
    channel_id: series_data["youtube_channel_id"],
    title_matcher: series_data["playlist_matcher"]
  )
  playlists.sort_by! { |playlist| playlist.year.to_i }
  playlists.select! { |playlist| playlist.videos_count.positive? }

  puts "  Found #{playlists.count} playlists"

  playlists.each do |playlist|
    event_dir = "#{Rails.root}/data/#{series_slug}/#{playlist.slug}"
    event_file = "#{event_dir}/event.yml"

    # Skip if event.yml already exists
    if File.exist?(event_file)
      puts "  Skipping (exists): #{playlist.slug}"
      next
    end

    FileUtils.mkdir_p(event_dir)
    File.write(event_file, YAML.dump(playlist.to_h.stringify_keys))
    puts "  Created: #{playlist.slug}/event.yml"
  end
end

# Main
if ARGV[0]
  # Process a specific series
  series_file = "#{Rails.root}/data/#{ARGV[0]}/series.yml"
  if File.exist?(series_file)
    create_events_for_series(series_file)
  else
    puts "Series not found: #{ARGV[0]}"
    puts "Expected file: #{series_file}"
    exit 1
  end
else
  # Process all series
  series_files = Dir.glob("#{Rails.root}/data/*/series.yml")
  puts "Found #{series_files.count} series to process"
  puts

  series_files.each do |series_file_path|
    create_events_for_series(series_file_path)
  end
end

puts
puts "Done!"
