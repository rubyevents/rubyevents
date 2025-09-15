class Avo::Filters::Canonical < Avo::Filters::BooleanFilter
  self.name = "Canonical"
  # self.visible = -> do
  #   true
  # end

  def apply(request, query, values)
    return query if values["canonical"] && values["not_canonical"]

    if values["canonical"]
      query = query.canonical
    elsif values["not_canonical"]
      query = query.not_canonical
    end
    query
  end

  def options
    {
      canonical: "Has canonical",
      not_canonical: "Without canonical"
    }
  end
end
