# frozen_string_literal: true

class EventLookupTool < RubyLLM::Tool
  description "Search for events by name, slug, location, kind, and/or date range. Returns matching events with their file paths for easy data updates."
  parameter :query, description: "Search query (matches against title, slug, location). Case-insensitive.", required: false
  parameter :start_date, description: "Start date (YYYY-MM-DD). Events ending on or after this date are included.", required: false
  parameter :end_date, description: "End date (YYYY-MM-DD). Events starting on or before this date are included.", required: false
  parameter :kind, description: "Type of event (one of: #{::Event.kinds.keys.join(", ")})", required: false

  def execute(query: nil, start_date: nil, end_date: nil, kind: nil)
    if kind.present? && !::Event.kinds.key?(kind)
      return {error: "Invalid kind '#{kind}'. Must be one of: #{::Event.kinds.keys.join(", ")}"}
    end

    events = Static::Event.all

    if query.present?
      query_downcase = query.downcase
      events = events.select { |event|
        event.title&.downcase&.include?(query_downcase) ||
          event.slug&.downcase&.include?(query_downcase) ||
          event.location&.downcase&.include?(query_downcase)
      }
    end

    start_date_parsed = parse_date(start_date) if start_date.present?
    if start_date_parsed
      events = events.select { |event|
        event_end = event.end_date
        event_end.is_a?(Date) && event_end >= start_date_parsed
      }
    end

    end_date_parsed = parse_date(end_date) if end_date.present?
    if end_date_parsed
      events = events.select { |event|
        event_start = event.start_date
        event_start.is_a?(Date) && event_start <= end_date_parsed
      }
    end

    if kind.present?
      events = events.select { |event| event.kind == kind }
    end

    events.map { |event| event_to_hash(event) }
  rescue => e
    {error: e.message}
  end

  private

  def parse_date(value)
    Date.parse(value)
  rescue Date::Error
    nil
  end

  def event_to_hash(event)
    base_path = File.dirname(event.project_file_path)

    {
      slug: event.slug,
      title: event.title,
      kind: event.kind,
      location: event.location,
      start_date: event.start_date&.to_s,
      end_date: event.end_date&.to_s,
      website: event.website,
      data_path: base_path,
      videos_file: "#{base_path}/videos.yml"
    }
  end
end
