# start this script with the rails runner command
# $ rails runner scripts/extract_videos.rb
#
# This script extracts videos from YouTube playlists for each event.
# You can optionally pass a series slug to only process that series:
#   rails runner scripts/extract_videos.rb railsconf
# Or pass both series and event slug:
#   rails runner scripts/extract_videos.rb railsconf railsconf-2024

def extract_videos_for_event(event_file_path)
  event_slug = File.basename(File.dirname(event_file_path))
  File.basename(File.dirname(event_file_path, 2))
  event_data = YAML.load_file(event_file_path)
  event = OpenStruct.new(event_data.merge("slug" => event_slug))

  # Skip if no playlist ID
  return if event.id.blank?

  puts "  Extracting videos for: #{event.title || event_slug}"

  playlist_videos = YouTube::PlaylistItems.new.all(playlist_id: event.id)
  playlist_videos.sort_by! { |video| video.published_at }

  # by default we use YouTube::VideoMetadata but in event.yml you can specify a different parser
  parser = event.metadata_parser&.constantize || YouTube::NullParser
  playlist_videos.map! { |metadata| parser.new(metadata: metadata, event_name: event.title).cleaned }

  videos_file = File.join(File.dirname(event_file_path), "videos.yml")
  puts "  #{playlist_videos.length} videos extracted"

  yaml = playlist_videos.map { |item| item.to_h.stringify_keys }.to_yaml

  yaml = yaml
    .gsub("- title:", "\n- title:") # Visually separate the talks with a newline
    .gsub("speakers:\n  -", "speakers:\n    -") # Indent the first speaker name for readability

  File.write(videos_file, yaml)
  puts "  Written to: #{videos_file}"
end

def extract_videos_for_series(series_slug)
  puts "Processing series: #{series_slug}"

  event_files = Dir.glob("#{Rails.root}/data/#{series_slug}/*/event.yml")
  puts "Found #{event_files.count} events"

  event_files.each do |event_file_path|
    extract_videos_for_event(event_file_path)
  end
end

# Main
if ARGV[0] && ARGV[1]
  # Process a specific event
  event_file = "#{Rails.root}/data/#{ARGV[0]}/#{ARGV[1]}/event.yml"
  if File.exist?(event_file)
    extract_videos_for_event(event_file)
  else
    puts "Event not found: #{ARGV[0]}/#{ARGV[1]}"
    puts "Expected file: #{event_file}"
    exit 1
  end
elsif ARGV[0]
  # Process a specific series
  series_dir = "#{Rails.root}/data/#{ARGV[0]}"
  if Dir.exist?(series_dir)
    extract_videos_for_series(ARGV[0])
  else
    puts "Series not found: #{ARGV[0]}"
    exit 1
  end
else
  # Process all series
  series_dirs = Dir.glob("#{Rails.root}/data/*/series.yml").map { |f| File.dirname(f) }
  puts "Found #{series_dirs.count} series to process"
  puts

  series_dirs.each do |series_dir|
    series_slug = File.basename(series_dir)
    extract_videos_for_series(series_slug)
    puts
  end
end

puts "Done!"
