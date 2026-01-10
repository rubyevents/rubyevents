# frozen_string_literal: true

# == Schema Information
#
# Table name: cities
# Database name: primary
#
#  id               :integer          not null, primary key
#  country_code     :string           not null, indexed => [name, state_code]
#  featured         :boolean          default(FALSE), not null, indexed
#  geocode_metadata :json             not null
#  latitude         :decimal(10, 6)
#  longitude        :decimal(10, 6)
#  name             :string           not null, indexed => [country_code, state_code]
#  slug             :string           not null, uniquely indexed
#  state_code       :string           indexed => [name, country_code]
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_cities_on_featured                              (featured)
#  index_cities_on_name_and_country_code_and_state_code  (name,country_code,state_code)
#  index_cities_on_slug                                  (slug) UNIQUE
#
class City < ApplicationRecord
  include Locatable
  include Sluggable

  configure_slug(attribute: :name, auto_suffix_on_collision: true)

  query_constraints :name, :country_code, :state_code

  geocoded_by :geocode_query do |record, results|
    if (result = results.first)
      record.latitude = result.latitude
      record.longitude = result.longitude
      record.geocode_metadata = result.data.merge("geocoded_at" => Time.current.iso8601)
      record.name = result.city || record.name
    end
  end

  has_many :events, primary_key: [:name, :country_code, :state_code], foreign_key: [:city, :country_code, :state_code], inverse_of: false
  has_many :users, -> { indexable.geocoded }, class_name: "User", primary_key: [:name, :country_code, :state_code], foreign_key: [:city, :country_code, :state_code], inverse_of: false

  before_validation :geocode, on: :create, if: -> { geocodeable? && !geocoded? }
  before_validation :clear_unsupported_state_code

  validates :name, presence: true, uniqueness: {scope: [:country_code, :state_code]}
  validates :slug, presence: true, uniqueness: true
  validates :country_code, presence: true

  scope :featured, -> { where(featured: true) }
  scope :for_country, ->(country_code) { where(country_code: country_code.upcase) }
  scope :for_state, ->(state) { where(country_code: state.country.alpha2, state_code: state.code) }

  def country
    @country ||= Country.find_by(country_code: country_code)
  end

  def state
    return nil unless state_code.present? && State.supported_country?(country)

    @state ||= State.find_by_code(state_code, country: country)
  end

  def path
    if featured?
      Router.city_path(slug)
    elsif state_code.present? && state.present?
      Router.city_with_state_path(country.code, state.slug, slug)
    else
      Router.city_by_country_path(country.code, slug)
    end
  end

  def past_path
    if featured?
      Router.city_past_index_path(self)
    elsif state_code.present? && state.present?
      Router.city_with_state_past_index_path(alpha2: country.code, state: state.slug, city: slug)
    else
      Router.city_by_country_past_index_path(alpha2: country.code, city: slug)
    end
  end

  def users_path
    if featured?
      Router.city_users_path(self)
    elsif state_code.present? && state.present?
      Router.city_with_state_users_path(alpha2: country.code, state: state.slug, city: slug)
    else
      Router.city_by_country_users_path(alpha2: country.code, city: slug)
    end
  end

  def stamps_path
    if featured?
      Router.city_stamps_path(self)
    elsif state_code.present? && state.present?
      Router.city_with_state_stamps_path(alpha2: country.code, state: state.slug, city: slug)
    else
      Router.city_by_country_stamps_path(alpha2: country.code, city: slug)
    end
  end

  def map_path
    if featured?
      Router.city_map_index_path(self)
    elsif state_code.present? && state.present?
      Router.city_with_state_map_index_path(alpha2: country.code, state: state.slug, city: slug)
    else
      Router.city_by_country_map_index_path(alpha2: country.code, city: slug)
    end
  end

  def subtitle
    location_string
  end

  def to_param
    slug
  end

  def geocoded?
    latitude.present? && longitude.present?
  end

  def geocodeable?
    name.present? && country_code.present?
  end

  def geocode_query
    [name, state&.name, country&.name].compact.join(", ")
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

  def alpha2
    country_code
  end

  def continent
    country&.continent
  end

  def bounds
    return nil unless geocoded?

    offset = 0.5

    {
      southwest: [longitude.to_f - offset, latitude.to_f - offset],
      northeast: [longitude.to_f + offset, latitude.to_f + offset]
    }
  end

  def stamps
    @stamps ||= begin
      event_stamps = events.flat_map { |event| Stamp.for_event(event) }
      country_stamps = Stamp.for(country_code: country_code, state_code: state_code)

      (event_stamps + country_stamps).uniq { |s| s.code }
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

  def nearby_events(radius_km: 250, limit: 12, exclude_ids: [])
    return [] unless coordinates.present?

    scope = Event.includes(:series, :participants)
      .where.not(latitude: nil, longitude: nil)
      .where.not(city: name)

    scope = scope.where.not(id: exclude_ids) if exclude_ids.any?

    scope.map do |event|
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

  def events_count
    @events_count ||= events.count
  end

  def users_count
    @users_count ||= users.count
  end

  def feature!
    update!(featured: true)
  end

  def unfeature!
    update!(featured: false)
  end

  private

  def clear_unsupported_state_code
    self.state_code = nil unless State.supported_country?(country)
  end

  class << self
    def find_for(city:, country_code:, state_code: nil)
      scope = where(name: city, country_code: country_code)
      scope = scope.where(state_code: state_code) if state_code.present?
      scope.first
    end

    def find_or_create_for(city:, country_code:, state_code: nil, latitude: nil, longitude: nil)
      return nil if city.blank? || country_code.blank?

      record = find_by(name: city, state_code: state_code, country_code: country_code)
      return record if record

      create(
        name: city,
        country_code: country_code.upcase,
        state_code: state_code,
        latitude: latitude,
        longitude: longitude,
        featured: false
      )
    end

    def featured_slugs
      @featured_slugs ||= featured.pluck(:slug).to_set
    end

    def clear_cache!
      @featured_slugs = nil
    end
  end
end
