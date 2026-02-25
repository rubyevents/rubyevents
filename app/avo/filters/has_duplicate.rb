class Avo::Filters::HasDuplicate < Avo::Filters::BooleanFilter
  self.name = "Has duplicate"

  def apply(request, query, values)
    if values["has_any_duplicate"]
      query.with_any_duplicate
    elsif values["has_reversed_name_duplicate"]
      query.with_reversed_name_duplicate
    elsif values["has_same_name_duplicate"]
      query.with_same_name_duplicate
    else
      query
    end
  end

  def options
    {
      has_any_duplicate: "Has any duplicate",
      has_reversed_name_duplicate: "Has reversed name duplicate",
      has_same_name_duplicate: "Has same name duplicate"
    }
  end
end
