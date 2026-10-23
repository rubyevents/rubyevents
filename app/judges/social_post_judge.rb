class SocialPostJudge < RubyLLM::Judge
  THRESHOLD = 0.7

  AREAS = %i[event_announced dates venue cfp talks schedule sponsors tickets recordings].freeze

  model "gpt-6-luna", provider: :openai

  probability :relevant, "Does this social media post contain new, concrete information about a Ruby conference or meetup that a database of Ruby events, talks, speakers, and recordings should capture?" do
    yes "A concrete announcement: a new event or edition, dates, venue, CFP, speakers, schedule, sponsors, tickets, or published videos or slides"
    no "General Ruby discussion, opinions, jokes, job posts, retweets without new facts, or anything not about a Ruby event"
  end

  choice :event_kind, "What kind of event is the post about?" do
    conference "A Ruby or Rails conference"
    meetup "A recurring Ruby or Rails meetup"
    other_event "A non-Ruby event, or a workshop, podcast, or livestream"
    none "Not about a specific event"
  end

  probability :event_announced, "Does the post announce a new event or a new edition of an event?"
  probability :dates, "Does the post announce or change the dates of an event?"
  probability :venue, "Does the post announce or change the city or venue of an event?"
  probability :cfp, "Does the post announce a call for proposals, or its opening, deadline, or extension?"
  probability :talks, "Does the post announce speakers, keynotes, or talks for an event?"
  probability :schedule, "Does the post announce that an event schedule or agenda is published?"
  probability :sponsors, "Does the post announce sponsors of an event?"
  probability :tickets, "Does the post announce that tickets are on sale, or change ticket availability?"
  probability :recordings, "Does the post announce published recordings, videos, or slides of talks?"

  def self.input_for(text:, platform:, author:, posted_at: nil, links: [], known_events: [])
    {
      platform: platform,
      author: author,
      posted_at: posted_at&.iso8601,
      text: text,
      links: links.presence,
      known_events: known_events.map { |event| event.to_h.slice("title", "start_date", "end_date", "website") }.presence
    }.compact
  end

  def self.relevant_areas(judgment, threshold: THRESHOLD)
    return [] if judgment.relevant.probability < threshold

    AREAS.select { |area| judgment.fetch(area).probability >= threshold }
  end
end
