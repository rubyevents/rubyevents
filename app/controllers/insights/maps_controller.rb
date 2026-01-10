class Insights::MapsController < ApplicationController
  skip_before_action :authenticate_user!

  def events
    data = Rails.cache.fetch("insights:maps:events", expires_in: 1.hour) do
      Event
        .where.not(latitude: nil, longitude: nil)
        .select(:id, :name, :slug, :latitude, :longitude, :city, :country_code, :start_date, :kind)
        .map do |event|
          {
            id: event.id,
            name: event.name,
            slug: event.slug,
            latitude: event.latitude,
            longitude: event.longitude,
            city: event.city,
            country_code: event.country_code,
            year: event.start_date&.year,
            kind: event.kind
          }
        end
    end

    render json: data
  end

  def speakers
    data = Rails.cache.fetch("insights:maps:speakers", expires_in: 1.hour) do
      User
        .speakers
        .where.not(latitude: nil, longitude: nil)
        .left_joins(:talks)
        .group(:id)
        .select("users.id, users.name, users.slug, users.latitude, users.longitude, users.city, users.country_code, COUNT(talks.id) as talk_count")
        .map do |speaker|
          {
            id: speaker.id,
            name: speaker.name,
            slug: speaker.slug,
            latitude: speaker.latitude,
            longitude: speaker.longitude,
            city: speaker.city,
            country_code: speaker.country_code,
            talk_count: speaker.talk_count
          }
        end
    end

    render json: data
  end
end
