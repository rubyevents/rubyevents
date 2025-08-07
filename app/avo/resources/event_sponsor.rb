class Avo::Resources::EventSponsor < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: params[:q], m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :event, as: :belongs_to
    field :sponsor, as: :belongs_to
  end
end
