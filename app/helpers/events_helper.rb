module EventsHelper
  def event_date_display(event, day_name: false)
    return "Date TBD" unless event.start_date.present?

    case event.date_precision
    when "year"
      "Sometime in #{event.start_date.year}"
    when "month"
      event.start_date.strftime("%B %Y")
    else
      if day_name
        "#{event.start_date.strftime("%b %-d")} #{event.start_date.strftime("%A")}"
      else
        event.start_date.strftime("%b %-d")
      end
    end
  end

  def event_date_group_key(event)
    return nil unless event.start_date.present?

    case event.date_precision
    when "year"
      "year-#{event.start_date.year}"
    when "month"
      "month-#{event.start_date.strftime("%Y-%m")}"
    else
      "day-#{event.start_date.to_date}"
    end
  end


  def group_events_by_date(events)
    events.group_by { |e| event_date_group_key(e) }
      .sort_by { |key, _| key || "zzz" }
      .map do |key, group_events|
        first_event = group_events.first

        display_info = {
          date: first_event.start_date,
          precision: first_event.date_precision,
          display: event_date_display(first_event, day_name: true)
        }

        [display_info, group_events]
      end
  end

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
