class Avo::Filters::Bio < Avo::Filters::TextFilter
  self.name = "Bio"
  self.button_label = "Filter by bio (contains)"

  def apply(request, query, value)
    query.where("bio LIKE ?", "%#{value}%")
  end
end
