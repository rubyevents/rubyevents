module TalksHelper
  def seconds_to_formatted_duration(seconds)
    Duration.seconds_to_formatted_duration(seconds, raise: false)
  end

  def talk_watch_status(talk)
    if talk.scheduled? || talk.parent_talk&.scheduled?
      {label: "Scheduled", icon: "clock"}
    elsif talk.not_recorded? || talk.parent_talk&.not_recorded?
      {label: "Not Recorded", icon: "video-slash"}
    elsif talk.not_published? || talk.parent_talk&.not_published?
      {label: "Not Published", icon: "upload"}
    elsif talk.video_unavailable?
      {label: "Unavailable", icon: "video-slash"}
    end
  end

  def ordering_title
    case order_by_key
    when "date_desc"
      "Newest first"
    when "date_asc"
      "Oldest first"
    when "ranked"
      "Relevance"
    end
  end

  def resource_icon(resource)
    case resource["type"]
    when "write-up", "blog", "article" then "pen-to-square"
    when "source-code", "code", "repo" then "code"
    when "github" then "github"
    when "documentation", "docs" then "book"
    when "slides", "presentation" then "presentation-screen"
    when "video" then "video"
    when "podcast", "audio" then "podcast"
    when "gem", "library" then "gem"
    when "transcript" then "file-lines"
    when "handout" then "file-pdf"
    when "notes" then "note-sticky"
    when "photos" then "images"
    when "book" then "book"
    else "link"
    end
  end

  def resource_display_title(resource)
    resource["title"].presence || resource["name"]
  end

  def resource_domain(resource)
    URI.parse(resource["url"]).host
  rescue URI::InvalidURIError
    resource["url"]
  end
end
