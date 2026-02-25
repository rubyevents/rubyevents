class Avo::Resources::GeocodeResult < Avo::BaseResource
  self.model_class = ::GeocodeResult
  self.title = :query
  self.includes = []
  self.search = {
    query: -> { query.where("query LIKE ?", "%#{params[:q]}%") }
  }

  def fields
    field :id, as: :id
    field :query, as: :text, link_to_record: true, sortable: true
    field :response_body, as: :code, language: "json", hide_on: :index
    field :created_at, as: :date_time, hide_on: :forms, sortable: true
    field :updated_at, as: :date_time, hide_on: :forms, sortable: true
  end
end
