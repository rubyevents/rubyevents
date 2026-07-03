class Avo::Filters::Orphaned < Avo::Filters::BooleanFilter
  self.name = "YAML Backing"

  def apply(request, query, values)
    if values["orphaned"]
      query = query.orphaned
    end

    if values["backed"]
      query = query.not_orphaned
    end

    query
  end

  def options
    {
      orphaned: "Orphaned (not in YAML)",
      backed: "Backed by YAML"
    }
  end
end
