module Prompts
  module Talk
    class EnhanceTranscript < Prompts::Base
      MODEL = "gpt-5-mini"

      def initialize(talk:)
        @talk = talk
      end

      private

      attr_reader :talk
      delegate :title, :description, :speakers, :event_name, :raw_transcript, to: :talk

      def system_message
        "You are a helpful assistant skilled in processing and summarizing transcripts."
      end

      def prompt
        <<~PROMPT
          You are tasked with improving and formatting a raw VTT transcript. Your goal is to correct and enhance the text, organize it into paragraphs, and format it into a specific JSON structure. Follow these instructions carefully to complete the task.

          First, here is the metadata for the transcript:
            - title: #{title}
            - description: #{description}
            - speaker name: #{speakers.map(&:name).to_sentence}
            - event name: #{event_name}

          Now, let's process the raw VTT transcript. Here's what you need to do:

          1. Read through the entire raw transcript carefully.

          2. Correct any spelling, grammar, or punctuation errors you find in the text.

          3. Improve the overall readability and coherence of the text without changing its meaning.

          4. Group related sentences into paragraphs. Each paragraph should contain a complete thought or topic.

          5. For each paragraph, use the start time of its first sentence as the paragraph's start time, and the end time of its last sentence as the paragraph's end time.

          6. Format the improved transcript into a JSON structure using this schema:
          {"transcript": [{start_time: "00:00:00", end_time: "00:00:05", text: "Hello, world!"},...]}

          Here is the raw VTT transcript to process:

          <raw_transcript>
          #{raw_transcript.to_vtt}
          </raw_transcript>

          To complete this task, follow these steps:

          1. Read through the entire raw transcript.
          2. Make necessary corrections to spelling, grammar, and punctuation.
          3. Improve the text for clarity and coherence.
          4. Group related sentences into paragraphs.
          5. Determine the start and end times for each paragraph.
          6. Format the improved transcript into the specified JSON structure.
          7. Aggregate the timestamps for the paragraphs and write them in the format "00:00:00". Don't include the milliseconds.

          Remember to preserve the original meaning of the content while making improvements. Ensure that each JSON object in the array represents a paragraph with its corresponding start time, end time, and improved text.

          Very important :
          - improve the entire transcript don't stop in the middle of the transcript.
          - do not add any other text than the transcript.
          - respect the original timestamps and aggregate correctly the timestamps for the paragraphs.
        PROMPT
      end

      def response_format
        {
          type: "json_schema",
          json_schema: {
            # strict: true,
            name: "talk_transcript",
            schema: {
              type: "object",
              properties: {
                transcript: {
                  type: "array",
                  items: {
                    type: "object",
                    properties: {
                      start_time: {type: "string"},
                      end_time: {type: "string"},
                      text: {type: "string"}
                    }
                  }
                }
              },
              required: ["transcript"],
              additionalProperties: false
            }
          }
        }
      end
    end
  end
end
