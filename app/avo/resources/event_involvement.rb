class Avo::Resources::EventInvolvement < Avo::BaseResource
  self.includes = [:involvementable, :event]

  self.search = {
    query: -> {
      query
        .left_joins("LEFT JOIN users ON users.id = event_involvements.involvementable_id AND event_involvements.involvementable_type = 'User'")
        .left_joins("LEFT JOIN organisations ON organisations.id = event_involvements.involvementable_id AND event_involvements.involvementable_type = 'Organisation'")
        .where("users.name LIKE ? OR organisations.name LIKE ? OR event_involvements.role LIKE ?", "%#{params[:q]}%", "%#{params[:q]}%", "%#{params[:q]}%")
    }
  }

  def fields
    field :id, as: :id
    field :involvementable, as: :belongs_to, polymorphic_as: :involvementable, types: [::User, ::Organisation], searchable: true
    field :event, as: :belongs_to, searchable: true, attach_scope: -> { query.order(name: :asc) }
    field :role, as: :text
    field :created_at, as: :date_time
    field :updated_at, as: :date_time
  end

  def filters
    filter Avo::Filters::InvolvementRole
  end
end
