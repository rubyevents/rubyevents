class PostDataJudge < RubyLLM::Judge
  THRESHOLD = 0.7

  AREAS = %i[dates venue cfp talks schedule sponsors tickets recordings].freeze

  model "gpt-6-luna", provider: :openai

  probability :already_present, "Is everything the post announces already reflected in current_data?"
  probability :needs_update, "Does the post contain information that is missing from or contradicts current_data, so the dataset should be updated?"

  probability :dates, "Does the post state event dates that differ from current_data.event start_date/end_date?"
  probability :venue, "Does the post name a city or venue missing from or different from current_data.event location and current_data.venue?"
  probability :cfp, "Does the post contain CFP information (opening, deadline, link) missing from or different from current_data.cfps?"
  probability :talks, "Does the post name speakers or talks missing from current_data.talks?"
  probability :schedule, "Does the post announce a schedule while current_data.schedule_present is false?"
  probability :sponsors, "Does the post name sponsors missing from current_data.sponsors?"
  probability :tickets, "Does the post link to a ticket shop missing from or different from current_data.event tickets_url?"
  probability :recordings, "Does the post announce recordings, videos, or slides missing from current_data.talks?"

  def self.input_for(post, event)
    {post: post, current_data: EventFreshnessJudge.current_data(event)}
  end

  def self.update_areas(judgment, threshold: THRESHOLD)
    AREAS.select { |area| judgment.fetch(area).probability >= threshold }
  end
end
