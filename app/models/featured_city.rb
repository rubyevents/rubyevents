# == Schema Information
#
# Table name: featured_cities
# Database name: primary
#
#  id           :integer          not null, primary key
#  city         :string           not null, indexed => [country_code]
#  country_code :string           not null, indexed => [city]
#  latitude     :decimal(10, 6)
#  longitude    :decimal(10, 6)
#  name         :string           not null
#  slug         :string           not null, uniquely indexed
#  state_code   :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_featured_cities_on_country_code_and_city  (country_code,city)
#  index_featured_cities_on_slug                   (slug) UNIQUE
#
class FeaturedCity < ApplicationRecord
  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :city, presence: true
  validates :country_code, presence: true

  def country
    @country ||= Country.find_by(country_code: country_code)
  end

  def state
    return nil unless state_code.present? && country&.alpha2 == "US"

    @state ||= State.find_by_code(state_code, country: country)
  end

  def events
    scope = Event.where(city: city, country_code: country_code)
    scope = scope.where(state: [state_code, state&.name].compact) if state_code.present?
    scope
  end

  def users
    scope = User.where(city: city, country_code: country_code)
    scope = scope.where(state: [state_code, state&.name].compact) if state_code.present?
    scope
  end

  def path
    "/cities/#{slug}"
  end

  def to_param
    slug
  end

  def geocoded?
    latitude.present? && longitude.present?
  end

  def coordinates
    return nil unless geocoded?

    [latitude, longitude]
  end

  def location_string
    if country&.alpha2 == "US" && state_code.present?
      "#{name}, #{state_code}"
    else
      "#{name}, #{country&.name}"
    end
  end

  def nearby_users(radius_km: 100, limit: 12, exclude_ids: [])
    return [] unless coordinates.present?

    User.geocoded
      .near(coordinates, radius_km, units: :km)
      .where.not(id: exclude_ids)
      .limit(limit)
      .map do |user|
        distance = Geocoder::Calculations.distance_between(
          coordinates,
          [user.latitude, user.longitude],
          units: :km
        )
        {user: user, distance_km: distance.round}
      end
      .sort_by { |u| u[:distance_km] }
  end

  def nearby_events(radius_km: 250, limit: 12)
    return [] unless coordinates.present?

    Event.includes(:series)
      .where.not(latitude: nil, longitude: nil)
      .where.not(city: city)
      .map do |event|
        distance = Geocoder::Calculations.distance_between(
          coordinates,
          [event.latitude, event.longitude],
          units: :km
        )
        {event: event, distance_km: distance.round} if distance <= radius_km
      end
      .compact
      .sort_by { |e| e[:event].start_date || Time.at(0).to_date }
      .last(limit)
      .reverse
  end

  def with_coordinates
    self
  end

  class << self
    def find_for(city:, country_code:, state_code: nil)
      scope = where(city: city, country_code: country_code)
      scope = scope.where(state_code: state_code) if state_code.present?
      scope.first
    end
  end
end
