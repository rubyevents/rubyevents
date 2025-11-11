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
    field :verified?, as: :boolean
    field :verified_at, as: :date_time, readonly: true
    field :attendance_details, as: :code, pretty_generated: true, readonly: true
  end

  def filters
    filter Avo::Filters::AttendedAs
  end

  def actions
    action Avo::Actions::ImportPassportScans
  end
end
