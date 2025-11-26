# start this script with the rails runner command
# $ rails runner scripts/prepare_series.rb
#
# This script updates series.yml files with youtube_channel_id if missing.
# You can optionally pass a series slug to only process that series:
#   rails runner scripts/prepare_series.rb railsconf

def add_youtube_channel_id(series_data)
  return series_data if series_data["youtube_channel_id"].present?
  return series_data if series_data["youtube_channel_name"].blank?

  youtube_channel_id = YouTube::Channels.new.id_by_name(channel_name: series_data["youtube_channel_name"])

  puts "  youtube_channel_id: #{youtube_channel_id}"
  series_data["youtube_channel_id"] = youtube_channel_id
  series_data
end

def process_series(series_file_path)
  series_slug = File.basename(File.dirname(series_file_path))
  puts "Processing: #{series_slug}"

  series_data = YAML.load_file(series_file_path)
  series_data = add_youtube_channel_id(series_data)

  File.write(series_file_path, YAML.dump(series_data))
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
