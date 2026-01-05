module Prompts
  module Talk
    class Topics < Prompts::Base
      MODEL = "gpt-5-mini"

      def initialize(talk:)
        @talk = talk
      end

      private

      attr_reader :talk
      delegate :title, :description, :speakers, :event_name, :transcript, to: :talk

      def system_message
        "You are a helpful assistant skilled in assigned a list of predefined topics to a transcript."
      end

      def prompt
        <<~PROMPT
          You are tasked with figuring out of the list of provided topics matches a transcript based on the transcript and its metadata. Follow these steps carefully:

          1. First, review the metadata of the video:
          <metadata>
            - title: #{title}
            - description: #{description}
            - speaker name: #{speakers.map(&:name).to_sentence}
            - event name: #{event_name}
          </metadata>

          2. Next, carefully read through the entire transcript:
          Note: The transcript is not perfect, it's a transcription of the video, so it might have some errors.
          <transcript>
          #{transcript.to_text}
          </transcript>

          3. Read through the entire list of exisiting topics for other talks.
          <topics>
            #{::Topic.approved.pluck(:name).join(", ")}
          </topics>

          3 bis. Read through the entire list of topics that we have already rejected for other talks.
          <rejected_topics>
            #{::Topic.rejected.pluck(:name).join(", ")}
          </rejected_topics>

          4. Pick 5 to 7 topics that would describe the talk best.
            You can pick any topic from the list of exisiting topics or create a new one.

            If you create a new topic, please ensure that it is relevant to the content of the transcript and match the recommended topics kind.
            Also for new topics please ensure they are not a synonym of an existing topic.
              - Make sure it fits the overall theme of this website, it's a website for Ruby related videos, so it should have something to do with Ruby, Web, Programming, Teams, People or Tech.
              - Ruby framework names (examples: Rails, Sinatra, Hanami, Ruby on Rails, ...)
              - Ruby gem names
              - Design patterns names (examples: MVC, MVP, Singleton, Observer, Strategy, Command, Decorator, Composite, Facade, Proxy, Mediator, Memento, Observer, State, Template Method, Visitor, ...)
              - Database names (examples: PostgreSQL, MySQL, MongoDB, Redis, Elasticsearch, Cassandra, CouchDB, SQLite, ...)
              - front end frameworks names (examples: React, Vue, Angular, Ember, Svelte, Stimulus, Preact, Hyperapp, Inferno, Solid, Mithril, Riot, Polymer, Web Components, Hotwire, Turbo, StimulusReflex, Strada ...)
              - front end CSS libraries and framework names (examples: Tailwind, Bootstrap, Bulma, Material UI, Foundation, ...)
              - front end JavaScript libraries names (examples: jQuery, D3, Chart.js, Lodash, Moment.js, ...)

            Topics are typically one or two words long, with some exceptions such as "Ruby on Rails"

          5. Format your topics you picked as a JSON object with the following schema:
            {
              "topics": ["topic1", "topic2", "topic3"]
            }

          6. Ensure that your summary is:
            - relevant to the content of the transcript and match the recommended topics kind
            - Free of personal opinions or external information not present in the provided content

          7. Output your JSON object containing the list of topics in the JSON format.
        PROMPT
      end

      def response_format
        {
          type: "json_schema",
          json_schema: {
            name: "talk_topics",
            schema: {
              type: "object",
              strict: true,
              properties: {
                topics: {
                  type: "array",
                  description: "A list of topics related to the ",
                  items: {
                    type: "string",
                    description: "A single topic."
                  }
                }
              },
              required: ["topics"],
              additionalProperties: false
            }
          }
        }
      end
    end
  end
end
