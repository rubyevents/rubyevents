module Prompts
  module Topic
    class SuggestGems < Prompts::Base
      MODEL = "gpt-4o-mini"

      def initialize(topics:)
        @topics = topics
      end

      private

      attr_reader :topics

      def system_message
        <<~SYSTEM
          You are a helpful assistant that maps Ruby conference talk topics to RubyGems.
          You have deep knowledge of the Ruby ecosystem, including popular gems, Rails components, and Ruby libraries.
        SYSTEM
      end

      def prompt
        <<~PROMPT
          You are tasked with mapping Ruby conference talk topics to their corresponding RubyGems packages.

          Here is a list of topics from Ruby conference talks, along with the number of talks for each topic:

          <topics>
          #{topics.map { |t| "- #{t.name} (#{t.talks_count} talks)" }.join("\n")}
          </topics>

          For each topic, determine if it DIRECTLY corresponds to one or more RubyGems packages.

          CRITICAL RULES:
          1. Only map a topic to a gem if the topic name IS the gem or a direct reference to it
          2. DO NOT map general/abstract concepts to gems, even if gems exist in that space:
             - "Testing" -> [] (NOT rspec, minitest, etc. - "Testing" is a concept, not a gem)
             - "Performance" -> [] (concept, not a gem)
             - "Security" -> [] (concept, not a gem)
             - "Debugging" -> [] (concept, not a gem)
             - "Refactoring" -> [] (concept, not a gem)
             - "API" -> [] (concept, not a gem)
             - "Database" -> [] (concept, not a gem)
             - "Caching" -> [] (concept, not a gem)
             - "Background Jobs" -> [] (concept, not a gem)
             - "Authentication" -> [] (concept, not a gem)
             - "Authorization" -> [] (concept, not a gem)
          3. Only suggest gems when the topic name matches or directly references the gem:
             - "RSpec" -> ["rspec"] (topic IS the gem name)
             - "Sidekiq" -> ["sidekiq"] (topic IS the gem name)
             - "Rails" or "Ruby on Rails" -> ["rails"] (direct reference)
             - "ActiveRecord" or "Active Record" -> ["activerecord"] (direct reference)
             - "Hotwire" -> ["turbo-rails", "stimulus-rails"] (Hotwire is the umbrella name for these gems)
             - "Turbo" -> ["turbo-rails"] (direct reference)
             - "Stimulus" -> ["stimulus-rails"] (direct reference)
          4. Use the exact gem name as it appears on RubyGems.org
          5. A topic can map to multiple gems only if it's an umbrella term for those specific gems
          6. When in doubt, return an empty array - it's better to miss a mapping than to incorrectly map a general concept

          Return a JSON object with the following schema:
          {
            "suggestions": [
              {
                "topic_name": "the exact topic name from the input",
                "gem_names": ["gem1", "gem2"] or [] if no gems apply,
                "confidence": "high" | "medium" | "low",
                "reasoning": "brief explanation of why these gems were chosen or why no gems apply"
              }
            ]
          }
        PROMPT
      end

      def response_format
        {
          type: "json_schema",
          json_schema: {
            name: "gem_suggestions",
            schema: {
              type: "object",
              strict: true,
              properties: {
                suggestions: {
                  type: "array",
                  items: {
                    type: "object",
                    properties: {
                      topic_name: {type: "string"},
                      gem_names: {
                        type: "array",
                        items: {type: "string"}
                      },
                      confidence: {
                        type: "string",
                        enum: ["high", "medium", "low"]
                      },
                      reasoning: {type: "string"}
                    },
                    required: ["topic_name", "gem_names", "confidence", "reasoning"],
                    additionalProperties: false
                  }
                }
              },
              required: ["suggestions"],
              additionalProperties: false
            }
          }
        }
      end
    end
  end
end
