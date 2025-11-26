# start this script with the rails runner command
# $ rails runner scripts/extract_videos.rb
# Once you have created the events it will retrieve the videos
#

organisations = YAML.load_file("#{Rails.root}/data_preparation/organisations.yml")

# for each event create a videos.yml file in its directory
def create_playlist_items(event, organisation_slug)
  puts "extracting videos for event: #{event.title}"
  playlist_videos = YouTube::PlaylistItems.new.all(playlist_id: event.id)
  playlist_videos.sort_by! { |video| video.published_at }

  event_dir = File.join(Rails.root, "data_preparation", organisation_slug, event.slug)
  FileUtils.mkdir_p(event_dir)

  # by default we use YouTube::VideoMetadata but in event.yml you can specify a different parser
  parser = event.metadata_parser&.constantize || YouTube::NullParser
  playlist_videos.map! { |metadata| parser.new(metadata: metadata, event_name: event.title).cleaned }

  path = "#{event_dir}/videos.yml"
  puts "#{playlist_videos.length} videos have been added to: #{event.title}"

  yaml = playlist_videos.map { |item| item.to_h.stringify_keys }.to_yaml

  yaml = yaml
    .gsub("- title:", "\n- title:") # Visually separate the talks with a newline
    .gsub("speakers:\n  -", "speakers:\n    -") # Indent the first speaker name for readability

  File.write(path, yaml)
end

# this is the main loop
organisations.each do |organisation|
  puts "extracting videos for #{organisation["slug"]}"
  event_files = Dir.glob("#{Rails.root}/data_preparation/#{organisation["slug"]}/*/event.yml")
  events = event_files.map { |path| OpenStruct.new(YAML.load_file(path)) }

  events.each do |event|
    create_playlist_items(event, organisation["slug"])
  end
end
