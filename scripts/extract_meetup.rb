# frozen_string_literal: true

require 'net/http'
require 'json'
require 'yaml'
require 'nokogiri'
require 'date'

# Pull data from some meetup event by specifying the URL. Outputs YAML 
#
# ruby scripts/extract_meetup.rb www.meetup.com/vienna-rb/events/307283556/
# ruby scripts/extract_meetup.rb www.meetup.com/vienna-rb/events/307283556/ >> data/vienna-rb/vienna-rb-meetup/videos.yml
def fetch_meetup(url)
  uri = URI("https://#{url}")
  request = Net::HTTP::Get.new(uri)
  request['User-Agent'] =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/109.0.0.0 Safari/537.36'

  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  response = http.request(request)

  if response.code != '200'
    puts "Error fetching meetup: #{response.code} - #{response.message}"
    return nil
  end

  doc = Nokogiri::HTML(response.body)

  url =~ %r{meetup\.com/([^/]+)/events}
  group = url[%r{meetup\.com/([^/]+)/events}, 1]

  title = doc.at_css('h1')&.text&.strip

  date_element = doc.at_css('div#event-info time, time')
  date_str = date_element&.attr('datetime')
  date = Date.parse(date_str) if date_str

  description_elements = doc.css('div#event-details div p')
  description = description_elements.map(&:text).join("\n\n")

  image_url = doc.at_css('picture[data-testid="event-description-image"] div img')&.attr('src')&.gsub('highres', '600')

  {
    'title' => title,
    'event_name' => title,
    'date' => date&.strftime('%Y-%m-%d'),
    'announced_at' => '',
    'published_at' => '',
    'video_provider' => 'children',
    'video_id' => "#{group}-#{title.to_s.downcase.gsub(/[^a-z0-9]+/, '-')}",
    'thumbnail_xs' => image_url,
    'thumbnail_sm' => image_url,
    'thumbnail_md' => image_url,
    'thumbnail_lg' => image_url,
    'thumbnail_xl' => image_url,
    'description' => description
  }
end

url = ARGV[0]
meetup_data = fetch_meetup(url)

# Note that to_yaml will break emoji characters. You will have to format your YAML after dumping it using `npm run format:yml`
#
# See https://github.com/rubyevents/rubyevents/pull/656
puts [meetup_data].to_yaml.lines[1..].join if meetup_data
