# frozen_string_literal: true

class EventSeriesLookupTool < RubyLLM::Tool
  description "Search for event series (conference organizers/recurring events) by name, slug, or kind. Returns matching series with their file paths for easy data updates."
  param :query, desc: "Search query (matches against name, slug, kind). Case-insensitive."

  def execute(query:)
    series = Static::EventSeries.all

    if query.present?
      query_downcase = query.downcase
      series = series.select { |s|
        s.name&.downcase&.include?(query_downcase) ||
          s.slug&.downcase&.include?(query_downcase) ||
          s.kind&.downcase&.include?(query_downcase)
      }
    end

    series.map { |s| series_to_hash(s) }
  rescue => e
    {error: e.message}
  end

  private

  def series_to_hash(series)
    {
      slug: series.slug,
      name: series.name,
      kind: series.kind,
      frequency: series.frequency,
      website: series.website,
      twitter: series.twitter,
      language: series.language,
      youtube_channel_id: series.youtube_channel_id,
      youtube_channel_name: series.youtube_channel_name,
      events_count: series.events.size,
      data_path: "data/#{series.slug}/series.yml"
    }.compact
  end
end
