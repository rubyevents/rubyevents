class Avo::Filters::TalkEvent < Avo::Filters::SelectFilter
  self.name = "Talk event"

  def apply(request, query, values)
    query.where(event_id: values) if values
  end

  def options
    Event.all.map { |event| [event.id, event.name] }.sort_by { |_, name| name }.to_h
  end
end
