class Avo::Resources::VerifiedEventParticipation < Avo::BaseResource
  self.includes = [:event]
  self.search = {
    query: -> { query.where("connect_id LIKE ?", "%#{params[:q].upcase}%") }
  }

  def fields
    field :id, as: :id
    field :connect_id, as: :text, sortable: true
    field :event, as: :belongs_to, searchable: true
    field :scanned_at, as: :date_time, sortable: true
    field :created_at, as: :date_time, sortable: true
  end
end
