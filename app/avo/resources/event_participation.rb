class Avo::Resources::EventParticipation < Avo::BaseResource
  self.includes = [:user, :event]
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: q, m: "or").result(distinct: false) }
  # }
  self.search = {
    query: -> { query.joins(:user).where("users.name LIKE ?", "%#{params[:q]}%") }
  }

  def fields
    field :id, as: :id
    field :attended_as, as: :select, enum: ::EventParticipation.attended_as
    field :user, as: :belongs_to, searchable: true
    field :event, as: :belongs_to, searchable: true, attach_scope: -> { query.order(name: :asc) }
  end

  def filters
    filter Avo::Filters::AttendedAs
  end
end
