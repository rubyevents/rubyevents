class Talk::Agents < ActiveRecord::AssociatedObject
  # Now that we use the tier flex option we add more retries as our request can be rejected if OpenAi is busy
  performs retries: 2 do
    # this is to comply to the rate limit of openai 60 000 tokens per minute
    limits_concurrency to: 4, key: "openai_api", duration: 1.hour
  end

  performs def improve_transcript
    return if talk.raw_transcript.blank?

    response = client.chat(
      parameters: Prompts::Talk::EnhanceTranscript.new(talk: talk).to_params,
      resource: talk,
      task_name: "enhance_transcript"
    )
    raw_response = JSON.repair(response.dig("choices", 0, "message", "content"))
    enhanced_json_transcript = JSON.parse(raw_response).dig("transcript")
    transcript = talk.talk_transcript || Talk::Transcript.new
    transcript.update!(enhanced_transcript: ::Transcript.create_from_json(enhanced_json_transcript))
  end

  performs def summarize
    return unless talk.raw_transcript.present?

    response = client.chat(
      parameters: Prompts::Talk::Summary.new(talk: talk).to_params,
      resource: talk,
      task_name: "summarize"
    )

    raw_response = JSON.repair(response.dig("choices", 0, "message", "content"))
    summary = JSON.parse(raw_response).dig("summary")
    talk.update!(summary: summary)
  end

  performs def analyze_topics
    return if talk.raw_transcript.blank?

    response = client.chat(
      parameters: Prompts::Talk::Topics.new(talk: talk).to_params,
      resource: talk,
      task_name: "analyze_topics"
    )

    raw_response = JSON.repair(response.dig("choices", 0, "message", "content"))
    topics = begin
      JSON.parse(raw_response)["topics"]
    rescue
      []
    end

    talk.topics = Topic.create_from_list(topics)
    talk.save!

    talk
  end


  performs def ingest
    talk.fetch_and_update_raw_transcript! unless talk.raw_transcript.present?
    talks.agents.improve_transcript unless talk.enhanced_transcript.present?
    talks.agents.summarize unless talk.summary.present?
    talks.agents.analyze_topics unless talk.topics.present?
  end

  private

  def client
    @client ||= LLM::Client.new
  end
end
