class Avo::Resources::EventParticipation < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: q, m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :user_id, as: :number
    field :event_id, as: :number
    field :attended_as, as: :select, enum: ::EventParticipation.attended_as
    field :user, as: :belongs_to
    field :event, as: :belongs_to
  end
end
