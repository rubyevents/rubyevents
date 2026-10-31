class Avo::Resources::Subscription < Avo::BaseResource
  self.model_class = ::Subscription
  self.includes = [:user, :subscribable]

  self.search = {
    query: -> { query.joins(:user).where("users.name LIKE ?", "%#{params[:q]}%") }
  }

  def fields
    field :id, as: :id
    field :user, as: :belongs_to, searchable: true
    field :subscribable, as: :belongs_to, polymorphic_as: :subscribable, types: [::EventSeries, ::User], searchable: true
    field :notes, as: :textarea
  end
end
