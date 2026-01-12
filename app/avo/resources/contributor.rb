class Avo::Resources::Contributor < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: q, m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :login, as: :text
    field :name, as: :text
    field :avatar_url, as: :text
    field :html_url, as: :text
  end
end
