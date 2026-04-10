class Avo::Filters::VideoAvailability < Avo::Filters::BooleanFilter
  self.name = "Video Availability"

  def apply(request, query, values)
    if values["available"]
      query = query.video_available
    end

    if values["unavailable"]
      query = query.video_unavailable
    end

    if values["watchable"]
      query = query.watchable
    end

    if values["marked_unavailable"]
      query = query.where.not(video_unavailable_at: nil)
    end

    query
  end

  def options
    {
      available: "Watchable & Available",
      unavailable: "Watchable & Unavailable",
      watchable: "Watchable",
      marked_unavailable: "Marked Unavailable"
    }
  end
end
