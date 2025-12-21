# frozen_string_literal: true

class EventLookupTool < RubyLLM::Tool
  description "Search for events by name, slug, location. Returns matching events with their file paths for easy data updates."
  param :query, desc: "Search query (matches against title, slug, location). Case-insensitive."

  def execute(query:)
    events = Static::Event.all

    if query.present?
      query_downcase = query.downcase
      events = events.select { |event|
        event.title&.downcase&.include?(query_downcase) ||
          event.slug&.downcase&.include?(query_downcase) ||
          event.location&.downcase&.include?(query_downcase)
      }
    end

    events.map { |event| event_to_hash(event) }
  rescue => e
    {error: e.message}
  end

  private

  def event_to_hash(event)
    base_path = File.dirname(event.send(:__file_path))

    {
      slug: event.slug,
      title: event.title,
      kind: event.kind,
      year: event.year,
      location: event.location,
      start_date: event.start_date&.to_s,
      end_date: event.end_date&.to_s,
      website: event.website,
      data_path: base_path.sub(Rails.root.to_s + "/", ""),
      videos_file: "#{base_path.sub(Rails.root.to_s + "/", "")}/videos.yml"
    }
  end
end
