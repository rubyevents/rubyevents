# This script will query the API and dump the speakers data to a YAML file
# speaker data can we updated in production, this is a way to sync our seed data to reflect as closely as possible the prod environment

require "net/http"
require "json"
require "yaml"

API_ENDPOINT = "https://www.rubyevents.org/speakers.json"
# API_ENDPOINT = "http://localhost:3000/speakers.json"
OUTPUT_FILE = "data/speakers.yml"

def fetch_speakers
  speakers = []
  current_page = 1

  loop do
    uri = URI("#{API_ENDPOINT}?page=#{current_page}&with_talks=false")
    response = Net::HTTP.get(uri)
    parsed_response = JSON.parse(response)

    speakers.concat(parsed_response["speakers"].map { |speaker| speaker.except("id", "updated_at", "created_at", "talks_count") })
    current_page += 1

    next_page = parsed_response.dig("pagination", "next_page")
    break if next_page.nil?
  end

  speakers
end

def save_to_yaml(data, file_name)
  File.write(file_name, data.to_yaml)
end

speakers_data = fetch_speakers
save_to_yaml(speakers_data, OUTPUT_FILE)

puts "Speakers data saved to #{OUTPUT_FILE}"

puts "formating with Prettier..."

system("yarn prettier --write #{OUTPUT_FILE}")

puts "Done!"
