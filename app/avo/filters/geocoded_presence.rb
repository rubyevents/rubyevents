class Avo::Filters::GeocodedPresence < Avo::Filters::BooleanFilter
  self.name = "Geocoded"

  def apply(request, query, values)
    return query if values["geocoded"] && values["not_geocoded"]

    if values["geocoded"]
      query.geocoded
    elsif values["not_geocoded"]
      query.not_geocoded
    else
      query
    end
  end

  def options
    {
      geocoded: "Geocoded",
      not_geocoded: "Not geocoded"
    }
  end
end
