class Talk::Agents < ActiveRecord::AssociatedObject
  # Now that we use the tier flex option we perform limited retries as our request can be rejected if OpenAI is busy
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
    enhanced_json_transcript = JSON.parse(response.dig("choices", 0, "message", "content")).dig("transcript")
    transcript = talk.talk_transcript || talk.talk_transcripts.build(language: talk.language)
    transcript.update!(enhanced_transcript: Talk::Transcript::CueList.from_json(enhanced_json_transcript))
  end

  performs def summarize
    return unless talk.raw_transcript.present?

    response = client.chat(
      parameters: Prompts::Talk::Summary.new(talk: talk).to_params,
      resource: talk,
      task_name: "summarize"
    )

    summary = JSON.parse(response.dig("choices", 0, "message", "content")).dig("summary")
    talk.update!(summary: summary)
  end

  performs def analyze_topics
    return if talk.raw_transcript.blank?

    response = client.chat(
      parameters: Prompts::Talk::Topics.new(talk: talk).to_params,
      resource: talk,
      task_name: "analyze_topics"
    )

    topics = begin
      JSON.parse(response.dig("choices", 0, "message", "content"))["topics"]
    rescue
      []
    end

    talk.topics = Topic.create_from_list(topics)
    talk.save!

    talk
  end

  performs def ingest
    talk.youtube_transcript.fetch_and_store! unless talk.raw_transcript.present?
    talk.agents.improve_transcript unless talk.enhanced_transcript.present?
    talk.agents.summarize unless talk.summary.present?
    talk.agents.analyze_topics unless talk.topics.present?
  end

  private

  def client
    @client ||= LLM::Client.new
  end
end
