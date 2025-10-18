class Avo::Filters::BioPresence < Avo::Filters::BooleanFilter
  self.name = "Bio presence"
  # self.visible = -> do
  #   true
  # end

  def apply(request, query, values)
    return query unless values["no_bio"]

    query.where(bio: [nil, ""])
  end

  def options
    {
      no_bio: "Without bio"
    }
  end
end
