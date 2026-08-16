class Avo::Filters::CFPEventKind < Avo::Filters::BooleanFilter
  self.name = "Event Kind"

  def apply(request, query, values)
    selected = options.keys.select { |key| values[key.to_s] }
    return query if selected.empty?

    query.joins(:event).where(events: {kind: selected})
  end

  def options
    {
      conference: "Conference",
      meetup: "Meetup",
      workshop: "Workshop",
      hackathon: "Hackathon",
      retreat: "Retreat"
    }
  end
end
