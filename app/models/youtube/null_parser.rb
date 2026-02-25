# This class is used to keep the raw metadata when you want to feed them to chat GPT
# for post processing
module YouTube
  class NullParser
    def initialize(metadata:, event_name:, options: {})
      @metadata = metadata
      @event_name = event_name
    end

    def cleaned
      OpenStruct.new(
        {
          title: @metadata.title,
          event_name: @event_name,
          description: @metadata.description,
          raw_title: @metadata.title,
          published_at: @metadata.published_at,
          video_provider: "youtube",
          video_id: @metadata.video_id
        }
      )
    end
  end
end
