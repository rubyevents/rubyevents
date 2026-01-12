module Prompts
  module Talk
    class Summary < Prompts::Base
      MODEL = "gpt-5"

      def initialize(talk:)
        @talk = talk
      end

      private

      attr_reader :talk
      delegate :title, :description, :speakers, :event_name, :transcript, to: :talk

      def system_message
        "You are a helpful assistant skilled in processing and summarizing transcripts."
      end

      def prompt
        <<~PROMPT
          You are tasked with creating a summary of a video based on its transcript and metadata. Follow these steps carefully:

          1. First, review the metadata of the video:
          <metadata>
            - title: #{title}
            - description: #{description}
            - speaker name: #{speakers.map(&:name).to_sentence}
            - event name: #{event_name}
          </metadata>

          2. Next, carefully read through the entire transcript:
          <transcript>
          #{transcript.to_text}
          </transcript>

          3. To summarize the video:
            a) Identify the main topic or theme of the video.
            b) Determine the key points discussed throughout the video.
            c) Note any significant examples, case studies, or anecdotes used to illustrate points.
            d) Capture any important conclusions or takeaways presented.
            e) Keep in mind the context provided by the metadata (title, description, speaker(s), and event).

          4. Create a summary that:
            - Introduces the main topic
            - Outlines the key points in a logical order
            - Includes relevant examples or illustrations if they are crucial to understanding the content
            - Concludes with the main takeaways or conclusions from the video
            - Is between 400-500 words in length
            - format it using markdown
            - use bullets for the key points

          5. exctract keywords
            - create a list of keywords to describe this video
            - 5 to 10 keywords
            - mostly teachnical keywords

          6. Format your summary as a JSON object with the following schema:
            {
              "summary": "Your summary text here using markdown",
              "keywords": ["keyword1", "keyword2", "keyword3"]
            }

          7. Ensure that your summary is:
            - Objective and factual, based solely on the content of the transcript and metadata
            - Written in clear, concise language
            - Free of personal opinions or external information not present in the provided content

          8. Output your JSON object containing the summary, ensuring it is properly formatted and enclosed in <answer> tags.

          9. Uses markdown for the summary to make it more readable define clear sections and uses bullets for the key points. do not use level 1 headings only start from level 2 (##).
        PROMPT
      end

      def response_format
        {
          type: "json_schema",
          json_schema: {
            strict: true,
            name: "talk_summary",
            schema: {
              type: "object",
              additionalProperties: false,
              required: ["summary", "keywords"],
              properties: {
                summary: {type: "string"},
                keywords: {
                  type: "array",
                  items: {type: "string"}
                }
              }
            }
          }
        }
      end
    end
  end
end
