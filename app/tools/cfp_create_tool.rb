# frozen_string_literal: true

class CFPCreateTool < RubyLLM::Tool
  description "Create a CFP (Call for Proposals) for an event. Writes to the event's cfp.yml file."

  param :event_query, desc: "Event slug or name to find (e.g., 'tropical-on-rails-2026' or 'Tropical on Rails 2026')"
  param :link, desc: "URL to the CFP submission page (e.g., 'https://cfp.example.com')"
  param :open_date, desc: "Date when CFP opens (YYYY-MM-DD format)", required: false
  param :close_date, desc: "Date when CFP closes (YYYY-MM-DD format)", required: false
  param :name, desc: "Optional name for this CFP (e.g., 'Lightning Talks CFP'). Only needed if the event has multiple CFPs.", required: false

  def execute(event_query:, link:, open_date: nil, close_date: nil, name: "Call for Proposals")
    event = find_event(event_query)
    return {error: "Event not found for query: #{event_query}"} if event.nil?

    result = event.cfp_file.add(
      link: link,
      open_date: open_date,
      close_date: close_date,
      name: name
    )

    return result if result.is_a?(Hash) && result[:error]

    {
      success: true,
      event: event.name,
      cfp_file: event.cfp_file.file_path.to_s.sub(Rails.root.to_s + "/", ""),
      cfp: result
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
end
