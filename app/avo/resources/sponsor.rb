class Avo::Resources::Sponsor < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: params[:q], m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :event, as: :belongs_to
    field :organization, as: :belongs_to
    field :tier, as: :text
    field :badge, as: :text
  end
end
