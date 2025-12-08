class Avo::Resources::Alias < Avo::BaseResource
  self.includes = [:aliasable]

  def fields
    field :id, as: :id
    field :aliasable, as: :belongs_to, polymorphic_as: :aliasable, types: [::User, ::Event, ::EventSeries, ::Organization]
    field :name, as: :text, required: true
    field :slug, as: :text, required: true
    field :created_at, as: :date_time, readonly: true
    field :updated_at, as: :date_time, readonly: true
  end
end
