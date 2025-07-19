class Avo::Resources::Sponsor < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: params[:q], m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :name, as: :text
    field :website, as: :text
    field :slug, as: :text
    field :logo_url, as: :text
    field :description, as: :textarea
  end
end
