class TalkTopicsJudge < RubyLLM::Judge
  LEVELS = [
    "Not discussed",
    "Mentioned in passing",
    "A secondary theme of the talk",
    "A primary subject of the talk"
  ].freeze

  MIN_SCORE = 2.3
  MAX_TOPICS = 7

  model "gpt-6-luna", provider: :openai

  def self.input_for(talk)
    {
      title: talk.title,
      description: talk.description.presence,
      summary: talk.summary.presence,
      speakers: talk.speakers.map(&:name).presence,
      event: talk.event&.name,
      transcript: talk.transcript&.to_text.presence
    }.compact
  end

  def self.questions_for(topics)
    topics.to_h do |topic|
      instructions = {
        question: "How central is this topic to the talk? Synonyms and closely related names count.",
        topic: topic.name,
        topic_description: topic.description.presence
      }.compact

      [topic.slug, {type: :score, instructions: instructions, levels: LEVELS}]
    end
  end

  def self.judge_topics(talk, topics)
    judge(input_for(talk), questions: questions_for(topics))
  end

  def self.pick(judgment, topics, min_score: MIN_SCORE, limit: MAX_TOPICS)
    topics
      .select { |topic| judgment.fetch(topic.slug).score >= min_score }
      .max_by(limit) { |topic| judgment.fetch(topic.slug).score }
  end
end
