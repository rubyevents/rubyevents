module Sociable
  extend ActiveSupport::Concern

  included do
    has_many :social_profiles, -> { order(:created_at) }, as: :sociable, dependent: :destroy
  end

  SocialProfile::PROVIDERS.each do |method|
    define_method(method) do
      social_profiles.send(method).first&.value
    end

    define_method(:"build_#{method}") do |value|
      social_profiles.build(provider: method, value:)
    end

    define_method(:"create_#{method}") do |value|
      social_profiles.create(provider: method, value:)
    end
  end
end
