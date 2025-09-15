class Avo::Filters::GitHub < Avo::Filters::BooleanFilter
  self.name = "GitHub handle"

  def apply(request, query, values)
    return query if values["has_github"] && values["no_github"]

    if values["has_github"]
      query = query.where.not(github: ["", nil])
    elsif values["no_github"]
      query = query.where(github: ["", nil])
    end

    query
  end

  def options
    {
      has_github: "With GitHub handle",
      no_github: "Without GitHub handle"
    }
  end
end
