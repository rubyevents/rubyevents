class Avo::Resources::User < Avo::BaseResource
  self.title = :name
  self.includes = [:speaker]
  self.search = {
    query: -> { query.where(email: params[:q]) }
  }

  def fields
    field :id, as: :id, link_to_record: true
    field :email, as: :text, link_to_record: true
    field :name, as: :text, link_to_record: true
    field :github_handle, as: :text, link_to_record: true
    field :admin, as: :boolean
    field :speaker, as: :belongs_to
    field :sessions, as: :has_many
    field :connected_accounts, as: :has_many
  end
end
