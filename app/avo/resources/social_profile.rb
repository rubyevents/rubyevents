class Avo::Resources::SocialProfile < Avo::BaseResource
  def fields
    field :id, as: :id
    field :provider, enum: ::SocialProfile.providers, as: :select, required: true
    field :value, as: :text
    field :sociable, as: :belongs_to, polymorphic_as: :sociable, types: [::Speaker, ::Event], foreign_key: :slug
  end
end
