class EventMatchJudge < RubyLLM::Judge
  NEW_EVENT = "new_event"
  NO_EVENT = "none"

  model "gpt-6-luna", provider: :openai
  inputs :candidates

  choice :event, "Which event is this social media post about?", -> {
    candidates
      .to_h { |event| [event.id, event.to_h.slice("title", "location", "start_date", "end_date", "website")] }
      .merge(
        NEW_EVENT => "An event that is not in this list, such as a newly announced edition of one of these series",
        NO_EVENT => "The post is not about one specific event"
      )
  }
end
