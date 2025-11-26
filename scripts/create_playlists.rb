# start this script with the rails runner command
# rails runner scripts/create_playlists.rb
#
organisations = YAML.load_file("#{Rails.root}/data_preparation/organisations.yml")

# create a directory for each event and add an event.yml file
def create_events(organisation)
  playlists = YouTube::Playlists.new.all(channel_id: organisation["youtube_channel_id"], title_matcher: organisation["playlist_matcher"])
  playlists.sort_by! { |playlist| playlist.year.to_i }
  playlists.select! { |playlist| playlist.videos_count.positive? }

  playlists.each do |playlist|
    event_dir = "#{Rails.root}/data_preparation/#{organisation["slug"]}/#{playlist.slug}"
    FileUtils.mkdir_p(event_dir)
    File.write("#{event_dir}/event.yml", playlist.to_h.stringify_keys.to_yaml)
  end
end

# This is the main loop
organisations.each do |organisation|
  FileUtils.mkdir_p(File.join("#{Rails.root}/data_preparation", organisation["slug"]))
  create_events(organisation)
end
