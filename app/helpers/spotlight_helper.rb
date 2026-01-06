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
end
