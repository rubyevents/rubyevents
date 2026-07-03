class Avo::Filters::AliasableType < Avo::Filters::SelectFilter
  self.name = "Aliasable Type"

  def apply(request, query, type)
    if type
      query.where(aliasable_type: type)
    else
      query
    end
  end

  def options
    {
      "User" => "User",
      "EventSeries" => "EventSeries",
      "Organization" => "Organization",
      "Talk" => "Talk"
    }
  end
end
