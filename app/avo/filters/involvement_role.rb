class Avo::Filters::InvolvementRole < Avo::Filters::SelectFilter
  self.name = "Role"

  def apply(request, query, role)
    if role
      query.where(role: role)
    else
      query
    end
  end

  def options
    EventInvolvement.distinct.pluck(:role).compact.sort.index_by(&:itself)
  end
end
