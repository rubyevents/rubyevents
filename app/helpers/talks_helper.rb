module TalksHelper
  def seconds_to_formatted_duration(seconds)
    Duration.seconds_to_formatted_duration(seconds, raise: false)
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
end
