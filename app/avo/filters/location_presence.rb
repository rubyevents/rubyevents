class Avo::Filters::LocationPresence < Avo::Filters::BooleanFilter
  self.name = "Location presence"

  def apply(request, query, values)
    return query if values["has_location"] && values["no_location"]

    if values["has_location"]
      query = query.where.not(location: ["", nil])
    elsif values["no_location"]
      query = query.where(location: ["", nil])
    end

    query
  end

  def options
    {
      has_location: "With location",
      no_location: "Without location"
    }
  end
end
