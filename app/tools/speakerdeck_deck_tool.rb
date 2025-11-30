# frozen_string_literal: true

class SpeakerdeckDeckTool < RubyLLM::Tool
  description "Fetch SpeakerDeck slide deck metadata by URL or username/slug using the oEmbed API"
  param :url, desc: "Full SpeakerDeck URL (e.g., 'https://speakerdeck.com/username/slug') or path as 'username/slug'"

  def execute(url:)
    normalized_url = normalize_url(url)
    response = client.oembed(normalized_url)

    {
      url: normalized_url,
      title: response.title,
      author_name: response.author_name,
      author_url: response.author_url,
      provider_name: response.provider_name,
      provider_url: response.provider_url,
      width: response.width,
      height: response.height,
      ratio: response.ratio,
      html: response.html
    }
  rescue => e
    {error: e.message}
  end

  private

  def client
    @client ||= Speakerdeck::Client.new
  end

  def normalize_url(url)
    if url.start_with?("http://", "https://")
      url
    else
      "https://speakerdeck.com/#{url}"
    end
  end
end
