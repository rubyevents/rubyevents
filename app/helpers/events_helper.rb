module EventsHelper
  def home_updated_text(event)
    if event.static_metadata.published_date
      return "Talks recordings were published #{time_ago_in_words(event.static_metadata.published_date)} ago."
    end

    if event.today?
      return "Takes place today."
    end

    if event.end_date&.past?
      return "Took place #{time_ago_in_words(event.end_date)} ago."
    end

    if event.start_date&.future?
      return "Takes place in #{time_ago_in_words(event.start_date)}."
    end

    if event.start_date&.future?
      "Takes place in #{time_ago_in_words(event.start_date)}."
    end
  end
end
