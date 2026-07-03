# frozen_string_literal: true

class VimeoVideoTool < RubyLLM::Tool
  description "Fetch Vimeo video metadata by video ID using the oEmbed API"
  param :id, desc: "Vimeo video ID"

  OEMBED_URL = "https://vimeo.com/api/oembed.json"

  def execute(id:)
    video_url = "https://vimeo.com/#{id}"
    uri = URI("#{OEMBED_URL}?url=#{CGI.escape(video_url)}")

    response = Net::HTTP.get_response(uri)

    unless response.is_a?(Net::HTTPSuccess)
      return {error: "Failed to fetch video: #{response.code} #{response.message}"}
    end

    data = JSON.parse(response.body)

    {
      id: id,
      title: data["title"],
      description: data["description"],
      duration: data["duration"],
      length: format_duration(data["duration"]),
      thumbnail_url: data["thumbnail_url"],
      author_name: data["author_name"],
      author_url: data["author_url"],
      upload_date: data["upload_date"],
      html: data["html"]
    }
  rescue => e
    {error: e.message}
  end

  private

  def format_duration(seconds)
    return nil unless seconds

    hours = seconds / 3600
    minutes = (seconds % 3600) / 60
    secs = seconds % 60

    if hours > 0
      format("%02d:%02d:%02d", hours, minutes, secs)
    else
      format("%02d:%02d", minutes, secs)
    end
  end
end
