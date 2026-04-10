# frozen_string_literal: true

class EventSeriesEventsTool < RubyLLM::Tool
  description "Get all events from an event series by name or slug. Returns the list of events within a conference series or meetup group."
  param :query, desc: "Event series slug (e.g., 'rails-world') or name (e.g., 'Rails World')"

  def execute(query:)
    series = Static::EventSeries.find_by_slug(query)
    series ||= Static::EventSeries.all.detect { |s| s.name&.downcase&.include?(query.downcase) }

    return {error: "Event series not found for '#{query}'"} if series.nil?

    events = series.events.sort_by { |e| e.start_date || Date.new(1900) }.reverse

    {
      series_slug: series.slug,
      series_name: series.name,
      kind: series.kind,
      frequency: series.frequency,
      website: series.website,
      data_path: "data/#{series.slug}/series.yml",
      events_count: events.size,
      events: events.map { |event| event_to_hash(event, series) }
    }
  rescue => e
    {error: e.message}
  end

  private

  def event_to_hash(event, series)
    base_path = "data/#{series.slug}/#{event.slug}"

    {
      slug: event.slug,
      title: event.title,
      kind: event.kind,
      year: event.year,
      location: event.location,
      start_date: event.start_date&.to_s,
      end_date: event.end_date&.to_s,
      website: event.website,
      data_path: base_path,
      videos_file: "#{base_path}/videos.yml"
    }.compact
  end
end
