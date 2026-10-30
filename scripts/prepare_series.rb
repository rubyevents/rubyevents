# TODO: remove this script

# start this script with the rails runner command
# $ rails runner scripts/prepare_series.rb
#
# This script updates series.yml files with youtube_channels if missing.
# You can optionally pass a series slug to only process that series:
#   rails runner scripts/prepare_series.rb railsconf

def add_youtube_channel(document)
  series_data = document.to_h
  return if series_data["youtube_channels"].present?

  # Try to look up channel by name if we have a playlist_matcher
  matcher = series_data["playlist_matcher"]
  return if matcher.blank?

  channel_id = YouTube::Channels.new.id_by_name(channel_name: matcher)
  return if channel_id.blank?

  puts "  youtube_channel_id: #{channel_id}"
  document["youtube_channels"] = [{"id" => channel_id}]
end

def process_series(series_file_path)
  series_slug = File.basename(File.dirname(series_file_path))
  puts "Processing: #{series_slug}"

  document = Yerba.parse_file(series_file_path)
  add_youtube_channel(document)

  document.save!
  puts "  Updated: #{series_file_path}"
end

# Main
if ARGV[0]
  # Process a specific series
  series_file = "#{Rails.root}/data/#{ARGV[0]}/series.yml"
  if File.exist?(series_file)
    process_series(series_file)
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
    process_series(series_file_path)
  end
end

puts
puts "Done!"
