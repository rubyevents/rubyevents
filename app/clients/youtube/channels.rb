require "open-uri"

module YouTube
  class Channels < YouTube::Client
    def id_by_name(channel_name:)
      response = get("/channels", query: {forUsername: "\"#{channel_name}\"", key: token, part: "snippet,contentDetails,statistics"})
      response.try(:items)&.first&.id || fallback_using_scrapping(channel_name: channel_name)
    end

    def get_details(channel_ids)
      Array(channel_ids).each_slice(50).each_with_object({}) do |batch, result|
        response = get("/channels", query: {id: batch.join(","), key: token, part: "snippet"})
        Array(response.try(:items)).each do |item|
          result[item["id"]] = {
            name: item.dig("snippet", "title"),
            handle: item.dig("snippet", "customUrl")
          }
        end
      end
    end

    private

    def default_headers
      {
        "Content-Type" => "application/json"
      }
    end

    def fallback_using_scrapping(channel_name:)
      # for some reason I was unable to get the channel id for paris-rb
      # this is a fallback solution using a scrapping approach
      html = URI.open("https://www.youtube.com/@#{channel_name}")
      doc = Nokogiri::HTML(html)

      meta_tag = doc.at_css('meta[itemprop="identifier"]')
      meta_tag["content"]
    end
  end
end
