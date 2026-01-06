# frozen_string_literal: true

class GeocodeEventJob < ApplicationJob
  queue_as :default

  def perform(event)
    event.geocode
    event.save!
  end
end
