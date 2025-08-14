# start this script with the rails runner command
# $ rails runner scripts/prepare_organisations.rb
#

organisations = YAML.load_file("#{Rails.root}/data_preparation/organisations.yml")

def add_youtube_channel_id(organisation)
  return organisation if organisation["youtube_channel_id"].present?

  youtube_channel_id = YouTube::Channels.new.id_by_name(channel_name: organisation["youtube_channel_name"])

  puts "youtube_channel_id: #{youtube_channel_id} is added to #{organisation["name"]}"
  organisation["youtube_channel_id"] = youtube_channel_id
  organisation
end
# add youtube_channel_id to organisations if missing
organisations.map! do |organisation|
  puts "processing #{organisation["name"]}"
  organisation["slug"] ||= organisation["name"].parameterize
  add_youtube_channel_id(organisation)
end

puts "processing all organisations done writing the result to #{Rails.root}/data_preparation/organisations.yml"
# save the YouTube channel id to the data_tmp/organisations.yml file
File.write("#{Rails.root}/data_preparation/organisations.yml", organisations.to_yaml)
