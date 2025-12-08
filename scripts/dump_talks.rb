# This script will query the API and dump the speakers data to a YAML file
# speaker data can we updated in production, this is a way to sync our seed data to reflect as closely as possible the prod environment

require "net/http"
require "json"
require "yaml"

API_ENDPOINT = "https://www.rubyevents.org/talks.json"
# API_ENDPOINT = "http://localhost:3000/talks.json"
OUTPUT_FILE = "data/talks.yml"

def fetch_talks
  talks = []
  current_page = 1

  loop do
    uri = URI("#{API_ENDPOINT}?page=#{current_page}&limit=1000")
    puts uri.inspect

    response = Net::HTTP.get(uri)
    parsed_response = JSON.parse(response)

    talks.concat(parsed_response["talks"].map { |talk| talk.slice(static_id", "slug", "title", "video_id", "video_provider") })
    current_page += 1
    break if parsed_response.dig("pagination", "next_page").nil?
  end

  talks
end

def save_to_yaml(data)
  File.write(OUTPUT_FILE, data.to_yaml)
end

puts talks_data = fetch_talks
save_to_yaml(talks_data)

puts "Talks data saved to #{OUTPUT_FILE}"

puts "formating with Prettier..."

system("yarn prettier --write #{OUTPUT_FILE}")

puts "Done!"
