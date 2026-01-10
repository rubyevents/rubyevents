# frozen_string_literal: true

class Continent
  include Locatable

  CONTINENT_DATA = {
    "africa" => {name: "Africa", alpha2: "AF", emoji: "🌍"},
    "antarctica" => {name: "Antarctica", alpha2: "AN", emoji: "🌎"},
    "asia" => {name: "Asia", alpha2: "AS", emoji: "🌏"},
    "australia" => {name: "Australia", alpha2: "OC", emoji: "🌏"},
    "europe" => {name: "Europe", alpha2: "EU", emoji: "🌍"},
    "north-america" => {name: "North America", alpha2: "NA", emoji: "🌎"},
    "south-america" => {name: "South America", alpha2: "SA", emoji: "🌎"}
  }.freeze

  BOUNDS = {
    "africa" => {southwest: [-25.0, -35.0], northeast: [60.0, 40.0]},
    "antarctica" => {southwest: [-180.0, -90.0], northeast: [180.0, -60.0]},
    "asia" => {southwest: [25.0, -10.0], northeast: [180.0, 80.0]},
    "australia" => {southwest: [110.0, -50.0], northeast: [180.0, 0.0]},
    "europe" => {southwest: [-25.0, 35.0], northeast: [60.0, 72.0]},
    "north-america" => {southwest: [-170.0, 7.0], northeast: [-50.0, 85.0]},
    "south-america" => {southwest: [-82.0, -56.0], northeast: [-34.0, 13.0]}
  }.freeze

  attr_reader :slug

  def initialize(slug)
    @slug = slug.to_s.parameterize
  end

  def name
    data[:name]
  end

  def alpha2
    data[:alpha2]
  end

  def emoji_flag
    data[:emoji]
  end

  def path
    Router.continent_path(self)
  end

  def past_path
    Router.continent_past_index_path(self)
  end

  def users_path
    Router.continent_users_path(self)
  end

  def countries_path
    Router.continent_countries_path(self)
  end

  def stamps_path
    Router.continent_stamps_path(self)
  end

  def map_path
    Router.continent_map_index_path(self)
  end

  def to_param
    slug
  end

  def bounds
    BOUNDS[slug]
  end

  def latitude
    return nil unless bounds

    (bounds[:southwest][1] + bounds[:northeast][1]) / 2.0
  end

  def longitude
    return nil unless bounds

    (bounds[:southwest][0] + bounds[:northeast][0]) / 2.0
  end

  def coordinates
    return nil unless latitude && longitude

    [longitude, latitude]
  end

  def countries
    @countries ||= Country.all.select { |country| country.continent_name == name }
  end

  def country_codes
    countries.map(&:alpha2)
  end

  def events
    Event.where(country_code: country_codes)
  end

  def users
    User.indexable.geocoded.where(country_code: country_codes)
  end

  def stamps
    Stamp.all.select { |stamp| stamp.has_country? && country_codes.include?(stamp.country&.alpha2) }
  end

  def ==(other)
    other.is_a?(Continent) && slug == other.slug
  end

  def eql?(other)
    self == other
  end

  def hash
    slug.hash
  end

  class << self
    def all
      @all ||= CONTINENT_DATA.keys.map { |slug| new(slug) }
    end

    def find(term)
      return nil if term.blank?

      slug = term.to_s.parameterize
      return nil unless CONTINENT_DATA.key?(slug)

      new(slug)
    end

    def find_by_name(name)
      return nil if name.blank?

      slug = CONTINENT_DATA.find { |_, data| data[:name] == name }&.first
      return nil unless slug

      new(slug)
    end

    def slugs
      CONTINENT_DATA.keys
    end

    def africa = new("africa")
    def antarctica = new("antarctica")
    def asia = new("asia")
    def australia = new("australia")
    def europe = new("europe")
    def north_america = new("north-america")
    def south_america = new("south-america")
  end

  private

  def data
    CONTINENT_DATA[slug] || {}
  end
end
