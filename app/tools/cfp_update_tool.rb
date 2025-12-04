# frozen_string_literal: true

class CFPUpdateTool < RubyLLM::Tool
  description "Update an existing CFP (Call for Proposals) for an event. Use this to add or modify dates on an existing CFP."

  param :event_query, desc: "Event slug or name to find (e.g., 'tropical-on-rails-2026' or 'Tropical on Rails 2026')"
  param :link, desc: "URL of the existing CFP to update"
  param :open_date, desc: "Date when CFP opens (YYYY-MM-DD format)", required: false
  param :close_date, desc: "Date when CFP closes (YYYY-MM-DD format)", required: false
  param :name, desc: "Name for this CFP (e.g., 'Lightning Talks CFP')", required: false

  def execute(event_query:, link:, open_date: nil, close_date: nil, name: nil)
    event = find_event(event_query)
    return {error: "Event not found for query: #{event_query}"} if event.nil?

    result = event.cfp_file.update(
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
