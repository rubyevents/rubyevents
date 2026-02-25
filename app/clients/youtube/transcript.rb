require "protobuf/message_type"

module YouTube
  class Transcript
    attr_reader :response

    def get(video_id)
      message = {one: "asr", two: "en"}
      typedef = MessageType
      two = get_base64_protobuf(message, typedef)

      message = {one: video_id, two: two}
      params = get_base64_protobuf(message, typedef)

      url = "https://www.youtube.com/youtubei/v1/get_transcript"
      headers = {"Content-Type" => "application/json"}
      body = {
        context: {
          client: {
            clientName: "WEB",
            clientVersion: "2.20240313"
          }
        },
        params: params
      }

      @response = HTTParty.post(url, headers: headers, body: body.to_json)
      JSON.parse(@response.body)
    end

    def self.get(video_id)
      new.get(video_id)
    end

    private

    def encode_message(message, typedef)
      encoded_message = typedef.new(message)
      encoded_message.to_proto
    end

    def get_base64_protobuf(message, typedef)
      encoded_data = encode_message(message, typedef)
      Base64.encode64(encoded_data).delete("\n")
    end
  end
end
