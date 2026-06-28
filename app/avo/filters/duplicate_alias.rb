class Avo::Filters::DuplicateAlias < Avo::Filters::BooleanFilter
  self.name = "Duplicate Aliases"

  def apply(request, query, values)
    if values["duplicate_alias"]
      query = query.duplicate_aliases
    end

    query
  end

  def options
    {
      duplicate_alias: "User exists for alias slug"
    }
  end
end
