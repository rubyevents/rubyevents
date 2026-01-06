# frozen_string_literal: true

class GeocodeUserJob < ApplicationJob
  queue_as :default

  def perform(user)
    return if user.location.blank?

    user.geocode
    user.save!
  end
end
