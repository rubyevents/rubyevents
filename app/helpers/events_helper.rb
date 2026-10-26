module EventsHelper
  MEETUP_LINK_LABELS = {
    "meetup" => ["Meetup.com", "meetup"],
    "luma" => ["Luma", "calendar"],
    "kommunity" => ["Kommunity", "users"],
    "website" => ["Website", "globe"],
    "tickets_url" => ["Tickets", "ticket"]
  }.freeze

  MEETUP_LINK_CALLS_TO_ACTION = {
    "meetup" => "Sign up or RSVP on Meetup.com",
    "luma" => "Register on Luma",
    "kommunity" => "RSVP on Kommunity",
    "tickets_url" => "Get tickets"
  }.freeze

  def meetup_link_label(field)
    MEETUP_LINK_LABELS.fetch(field) { [field.humanize, "link"] }.first
  end

  def meetup_link_text(field, event)
    return MEETUP_LINK_CALLS_TO_ACTION[field] if meetup_link_call_to_action?(field, event)
    return "View on #{meetup_link_label(field)}" if MeetupLinks::PLATFORMS.include?(field)

    meetup_link_label(field)
  end

  def meetup_link_call_to_action?(field, event)
    event.upcoming? && MEETUP_LINK_CALLS_TO_ACTION.key?(field)
  end

  def link_handle(field, url)
    uri = URI.parse(url.to_s)
    segments = uri.path.to_s.split("/").compact_blank
    host = uri.host.to_s.delete_prefix("www.")

    case field
    when "website"
      host
    when "twitter", "instagram"
      "@#{segments.first.to_s.delete_prefix("@")}"
    when "mastodon"
      "#{segments.first}@#{host}"
    when "bsky", "linkedin"
      segments.last
    else
      segments.first
    end.presence
  rescue URI::InvalidURIError
    nil
  end

  def group_links_noun(links)
    return "pages" unless links.one?

    field = links.keys.first

    (field == "website") ? "website" : "#{meetup_link_label(field)} page"
  end

  def meetup_link_icon(field, **options)
    icon = MEETUP_LINK_LABELS.dig(field, 1) || "link"

    (field == "meetup") ? fab(icon, **options) : fa(icon, **options)
  end

  def meetup_time_range(event)
    times = [event.static_metadata.start_time, event.static_metadata.end_time].compact_blank

    times.join(" - ").presence
  end

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

  def continent_filter_path(continent)
    url_for(continent: continent&.slug, kind: params[:kind].presence)
  end

  def kind_filter_path(kind)
    url_for(kind: kind, continent: params[:continent].presence)
  end

  def featured_cta_path(event)
    if event.featured_reason == :cfp_closing
      event_cfp_index_path(event)
    elsif event.tickets.available?
      event_tickets_path(event)
    else
      event_path(event)
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
