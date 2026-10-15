class Avo::Resources::EventSeriesSubscription < Avo::BaseResource
  self.model_class = ::EventSeriesSubscription
  self.includes = [:user, :event_series]

  self.search = {
    query: -> { query.joins(:user).where("users.name LIKE ?", "%#{params[:q]}%") }
  }

  def fields
    field :id, as: :id
    field :user, as: :belongs_to, searchable: true
    field :event_series, as: :belongs_to, searchable: true, attach_scope: -> { query.order(name: :asc) }
  end
end
