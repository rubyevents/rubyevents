# start this script with the rails runner command
# rails runner scripts/create_playlists.rb
#
organisations = YAML.load_file("#{Rails.root}/data_preparation/organisations.yml")

# create a directory for each organisation and add a playlist.yml file
def create_playlists(organisation)
  playlists = YouTube::Playlists.new.all(channel_id: organisation["youtube_channel_id"], title_matcher: organisation["playlist_matcher"])
  playlists.sort_by! { |playlist| playlist.year.to_i }
  playlists.select! { |playlist| playlist.videos_count.positive? }

  File.write("#{Rails.root}/data_preparation/#{organisation["slug"]}/playlists.yml", playlists.map { |item| item.to_h.stringify_keys }.to_yaml.gsub("- id: ", "\n- id: "))
end

# This is the main loop
organisations.each do |organisation|
  FileUtils.mkdir_p(File.join("#{Rails.root}/data_preparation", organisation["slug"]))
  create_playlists(organisation)
end
