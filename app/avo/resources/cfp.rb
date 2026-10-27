class Avo::Resources::CFP < Avo::BaseResource
  self.title = :name

  def fields
    field :id, as: :id
    field :name, as: :text, link_to_record: true
    field :link, as: :text
    field :open_date, as: :date
    field :close_date, as: :date
    field :status, as: :status, loading_when: [:pending], success_when: [:open], failed_when: [:closed], hide_on: [:forms]
    field :days_remaining, as: :number, hide_on: [:forms, :index]
    field :event, as: :belongs_to, searchable: true
    field :event_series, as: :belongs_to, searchable: true, help: "For an always-open CFP of a meetup group, instead of an event"
  end

  def filters
    filter Avo::Filters::CFPStatus
    filter Avo::Filters::CFPEventKind
  end
end
