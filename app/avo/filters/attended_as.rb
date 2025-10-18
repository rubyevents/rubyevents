class Avo::Filters::AttendedAs < Avo::Filters::SelectFilter
  self.name = "Attended as"

  def apply(request, query, attended_as)
    if attended_as
      query.where("attended_as is ?", attended_as)
    else
      query
    end
  end

  def options
    EventParticipation.attended_as
  end
end
