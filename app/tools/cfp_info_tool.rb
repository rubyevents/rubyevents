# frozen_string_literal: true

class CFPInfoTool < RubyLLM::Tool
  description "Get CFP (Call for Proposals) information for an event. Returns all CFPs with their links, dates, and status."

  param :event_query, desc: "Event slug or name to find (e.g., 'tropical-on-rails-2026' or 'Tropical on Rails 2026')"

  def execute(event_query:)
    event = find_event(event_query)
    return {error: "Event not found for query: #{event_query}"} if event.nil?

    cfps = event.cfp_file.entries

    return {event: event.name, cfps: [], message: "No CFPs found for this event"} if cfps.empty?

    {
      event: event.name,
      cfp_file: event.cfp_file.file_path.to_s.sub(Rails.root.to_s + "/", ""),
      cfps: cfps.map { |cfp| format_cfp(cfp) }
    }
  rescue => e
    {error: e.message}
  end

  private

  def find_event(query)
    Event.find_by(slug: query) ||
      Event.find_by(slug: query.parameterize) ||
      Event.find_by(name: query) ||
      Event.ft_search(query).first
  end

  def format_cfp(cfp)
    {
      name: cfp["name"],
      link: cfp["link"],
      open_date: cfp["open_date"],
      close_date: cfp["close_date"],
      status: cfp_status(cfp)
    }
  end

  def cfp_status(cfp)
    today = Date.current
    open_date = cfp["open_date"] ? Date.parse(cfp["open_date"]) : nil
    close_date = cfp["close_date"] ? Date.parse(cfp["close_date"]) : nil

    if close_date && today > close_date
      "closed"
    elsif open_date && today < open_date
      "upcoming"
    elsif open_date && (close_date.nil? || today <= close_date)
      "open"
    else
      "unknown"
    end
  end
end
