module Prompts
  module Topic
    class MatchTalks < Prompts::Base
      MODEL = "gpt-4.1"

      def initialize(topic:, talks:)
        @topic = topic
        @talks = talks
      end

      private

      attr_reader :topic, :talks

      def system_message
        <<~SYSTEM
          You are a helpful assistant that determines whether Ruby conference talks are relevant to a specific topic.
          You have deep knowledge of the Ruby ecosystem, programming concepts, and software development.
        SYSTEM
      end

      def prompt
        <<~PROMPT
          You are tasked with determining which talks from a list are actually about or significantly related to a specific topic.

          The topic is: "#{topic.name}"
          #{"Topic description: #{topic.description}" if topic.description.present?}

          Here are the candidate talks to evaluate:

          <talks>
          #{talks_info}
          </talks>

          For each talk, determine if it is actually about or significantly discusses the topic "#{topic.name}".

          IMPORTANT RULES:
          1. A talk matches if the topic is a PRIMARY subject of the talk, not just a passing mention
          2. Consider the title, description, summary, and speaker context
          3. Be VERY strict - only mark as matching with "high" confidence if you're absolutely certain the talk substantially covers the topic
          4. False positives are worse than false negatives - when in doubt, mark as not matching or use "low" confidence
          5. Consider synonyms and related terms (e.g., "Ruby on Rails" matches "Rails")
          6. Only talks with "high" confidence will be assigned to the topic, so be conservative

          Return a JSON object with the following schema:
          {
            "matches": [
              {
                "talk_id": <integer>,
                "matches": true | false,
                "confidence": "high" | "medium" | "low",
                "reasoning": "brief explanation"
              }
            ]
          }
        PROMPT
      end

      def talks_info
        talks.map do |talk|
          <<~TALK
            - ID: #{talk.id}
              Title: #{talk.title}
              Description: #{talk.description.presence || "N/A"}
              Summary: #{talk.summary.presence || "N/A"}
              Speakers: #{talk.speakers.map(&:name).join(", ").presence || "N/A"}
              Event: #{talk.event&.name || "N/A"}
          TALK
        end.join("\n")
      end

      def response_format
        {
          type: "json_schema",
          json_schema: {
            name: "talk_matches",
            schema: {
              type: "object",
              strict: true,
              properties: {
                matches: {
                  type: "array",
                  items: {
                    type: "object",
                    properties: {
                      talk_id: {type: "integer"},
                      matches: {type: "boolean"},
                      confidence: {
                        type: "string",
                        enum: ["high", "medium", "low"]
                      },
                      reasoning: {type: "string"}
                    },
                    required: ["talk_id", "matches", "confidence", "reasoning"],
                    additionalProperties: false
                  }
                }
              },
              required: ["matches"],
              additionalProperties: false
            }
          }
        }
      end
    end
  end
end
