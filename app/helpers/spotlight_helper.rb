module SpotlightHelper
  def spotlight_resources
    %w[talks speakers events]
  end

  def spotlight_main_resource
    request.path.split("/").last.presence_in(%w[talks speakers events topics]) || "talks"
  end

  def spotlight_main_resource_path
    {
      "talks" => talks_path,
      "speakers" => speakers_path,
      "events" => archive_events_path,
      "topics" => topics_path
    }.fetch(spotlight_main_resource, spotlight_talks_path)
  end

  def spotlight_search_backend
    @spotlight_search_backend ||= Search::Backend.resolve.name
  end

  def spotlight_can_search_locations?
    spotlight_search_backend != :sqlite_fts
  end

  def spotlight_can_search_languages?
    spotlight_search_backend != :sqlite_fts
  end

  def spotlight_can_search_series?
    spotlight_search_backend != :sqlite_fts
  end
end
