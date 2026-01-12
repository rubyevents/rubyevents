class Avo::Filters::GitHubHandlePresence < Avo::Filters::BooleanFilter
  self.name = "GitHub handle presence"

  def apply(request, query, values)
    return query if values["has_github"] && values["no_github"]
    if values["has_github"]
      query = query.where.not(github_handle: ["", nil])
    elsif values["no_github"]
      query = query.where(github_handle: ["", nil])
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
