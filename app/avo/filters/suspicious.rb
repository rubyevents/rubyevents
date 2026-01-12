class Avo::Filters::Suspicious < Avo::Filters::BooleanFilter
  self.name = "Suspicious"

  def apply(request, query, values)
    return query unless values["suspicious"]

    query.suspicious
  end

  def options
    {
      suspicious: "Suspicious users"
    }
  end
end
