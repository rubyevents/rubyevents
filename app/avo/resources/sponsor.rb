class Avo::Resources::Sponsor < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: params[:q], m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :event, as: :belongs_to
    field :event_series, as: :belongs_to, help: "For a sponsor of a whole meetup group, instead of an event"
    field :organization, as: :belongs_to
    field :tier, as: :text
    field :badge, as: :text
    field :started_on, as: :date, hide_on: :index
    field :ended_on, as: :date, hide_on: :index
  end
end
