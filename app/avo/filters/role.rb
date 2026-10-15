class Avo::Filters::Role < Avo::Filters::SelectFilter
  self.name = "Role"

  def apply(request, query, role)
    if role
      query.where(role:)
    else
      query
    end
  end

  def options
    EventParticipation.roles
  end
end
