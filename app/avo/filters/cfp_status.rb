class Avo::Filters::CFPStatus < Avo::Filters::BooleanFilter
  self.name = "Status"

  def apply(request, query, values)
    query = query.open if values["open"]
    query = query.closed if values["closed"]
    query = query.where(close_date: nil) if values["open_ended"]
    query = query.where(open_date: nil, close_date: nil) if values["always_open"]
    query
  end

  def options
    {
      open: "Open",
      closed: "Closed",
      open_ended: "Open-ended (no close date)",
      always_open: "Always open (no dates)"
    }
  end
end
