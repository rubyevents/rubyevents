class Avo::Resources::Organization < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: params[:q], m: "or").result(distinct: false) }
  # }
  self.find_record_method = -> {
    if id.is_a?(Array)
      query.where(slug: id)
    else
      query.find_by(slug: id)
    end
  }

  def fields
    field :id, as: :id
    field :name, as: :text
    field :kind, as: :select, enum: ::Organization.kinds
    field :website, as: :text
    field :slug, as: :text
    field :description, as: :textarea
    field :main_location, as: :text
    field :sponsors, as: :has_many
    field :event_involvements, as: :has_many
  end
end
