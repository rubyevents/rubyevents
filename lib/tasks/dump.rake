TALKS_SLUGS_FILE = "data/talks_slugs.yml"
API_ENDPOINT = "https://www.rubyevents.org/talks.json"
# API_ENDPOINT = "http://localhost:3000/talks.json"

namespace :dump do
  desc "dump talks slugs to a local yml file"
  task talks_slugs: :environment do
    data = YAML.load_file(TALKS_SLUGS_FILE)
    dump_updated_at = data&.dig("updated_at")

    talks_slugs = data&.dig("talks_slugs") || {}
    current_page = 1

    loop do
      uri = URI("#{API_ENDPOINT}?page=#{current_page}&limit=500&all=true&sort=created_at_asc&created_after=#{dump_updated_at}")
      response = Net::HTTP.get(uri)
      parsed_response = JSON.parse(response)

      parsed_response["talks"].each do |talk|
        video_id = talk["video_id"]
        next if video_id.nil? || video_id == ""

        talks_slugs[video_id] = talk.dig("slug")
      end

      current_page += 1
      total_pages = parsed_response.dig("pagination", "total_pages")
      break if parsed_response.dig("pagination", "next_page").nil? || current_page > total_pages
    end
    data = {"updated_at" => Time.current.to_date.to_s, "talks_slugs" => talks_slugs}.to_yaml
    File.write("data/talks_slugs.yml", data)

    data = YAML.load_file(TALKS_SLUGS_FILE)
    puts "Total talks slugs: #{data.dig("talks_slugs").size}"
  end
end
