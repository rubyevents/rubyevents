class TopicMatchJudge < RubyLLM::Judge
  model "gpt-6-luna", provider: :openai
  inputs :topic

  probability :matches, -> {
    {
      question: "Is this Ruby conference talk primarily about the given topic?",
      topic: topic.name,
      topic_description: topic.description.presence
    }.compact
  } do
    yes "The topic is a primary subject of the talk, substantially covered by its title, description, or summary. Synonyms and closely related names count, e.g. \"Ruby on Rails\" for \"Rails\"."
    no "The topic is only mentioned in passing, is merely adjacent to the talk's subject, or is not discussed at all."
  end

  def self.input_for(talk)
    {
      title: talk.title,
      description: talk.description.presence,
      summary: talk.summary.presence,
      speakers: talk.speakers.map(&:name),
      event: talk.event&.name
    }.compact
  end
end
