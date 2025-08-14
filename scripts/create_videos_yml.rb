# start this script with the rails runner command
# $ rails runner scripts/create_videos_yml.rb [playlist_id]
#

playlist_id = ARGV[0]

if playlist_id.blank?
  puts "Please provide a playlist id"
  exit 1
end

puts YouTube::PlaylistItems.new
  .all(playlist_id: playlist_id)
  .map { |metadata| YouTube::VideoMetadata.new(metadata: metadata, event_name: "TODO").cleaned }
  .map { |item| item.to_h.stringify_keys }
  .to_yaml
  .gsub("- title:", "\n- title:") # Visually separate the talks with a newline
