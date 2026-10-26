class Avo::Filters::CFPEventKind < Avo::Filters::BooleanFilter
  self.name = "Event Kind"

  def apply(request, query, values)
    selected = options.keys.select { |key| values[key.to_s] }
    return query if selected.empty?

    owned = query.left_joins(:event, :event_series)
    series_kinds = selected.map(&:to_s) & ::EventSeries.kinds.keys

    owned.where(events: {kind: selected}).or(owned.where(event_series: {kind: series_kinds}))
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
