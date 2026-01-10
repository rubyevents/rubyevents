class State
  SUPPORTED_COUNTRIES = %w[US GB AU CA].freeze
  UK_NATIONS = %w[ENG SCT WLS NIR].freeze

  attr_reader :code, :name, :country

  def initialize(code:, name:, country:)
    @code = code
    @name = name
    @country = country
  end

  def slug
    name.parameterize
  end

  def abbreviation
    code
  end

  def display_name
    if country.alpha2 == "GB"
      name
    else
      abbreviation
    end
  end

  def path
    if country.alpha2 == "GB"
      Router.country_path(slug)
    else
      Router.state_path(country.code, slug)
    end
  end

  def past_path
    Router.state_past_index_path(state_alpha2: country.code, state_slug: slug)
  end

  def users_path
    Router.state_users_path(state_alpha2: country.code, state_slug: slug)
  end

  def cities_path
    Router.state_cities_path(state_alpha2: country.code, state_slug: slug)
  end

  def stamps_path
    Router.state_stamps_path(state_alpha2: country.code, state_slug: slug)
  end

  def map_path
    Router.state_map_index_path(state_alpha2: country.code, state_slug: slug)
  end

  def subtitle
    "#{name}, #{country.name}"
  end

  def has_routes?
    true
  end

  def to_param
    slug
  end

  def ==(other)
    other.is_a?(State) && code == other.code && country.alpha2 == other.country.alpha2
  end

  def eql?(other)
    self == other
  end

  def hash
    [code, country.alpha2].hash
  end

  def events
    Event.where(country_code: country.alpha2, state_code: [code, name])
  end

  def users
    User.indexable.geocoded.where(country_code: country.alpha2, state_code: [code, name])
  end

  def cities
    City.for_state(self)
  end

  def stamps
    state_events = events.to_a
    Stamp.all.select { |stamp| stamp.has_event? && state_events.include?(stamp.event) }
  end

  def alpha2
    country.alpha2
  end

  def country_code
    country.alpha2
  end

  def geocoded?
    false
  end

  def bounds
    nil
  end

  def to_location
    Location.new(state: code, country_code: country.alpha2)
  end

  class << self
    def supported_country?(country)
      return false if country.blank?

      SUPPORTED_COUNTRIES.include?(country.alpha2)
    end

    def find(country:, term:)
      return nil if term.blank? || country.blank?
      return nil unless supported_country?(country)

      term_slug = term.to_s.parameterize
      term_upper = term.to_s.upcase
      term_downcase = term.to_s.downcase

      for_country(country).find do |state|
        state.slug == term_slug ||
          state.code.upcase == term_upper ||
          state.name.downcase == term_downcase
      end
    end

    def find_by_slug(slug)
      return nil if slug.blank?

      us_states.find { |state| state.slug == slug.to_s.parameterize }
    end

    def find_by_code(code, country: nil)
      return nil if code.blank?

      if country
        for_country(country).find { |state| state.code.upcase == code.upcase }
      else
        SUPPORTED_COUNTRIES.each do |country_code|
          country = Country.find(country_code)
          state = for_country(country).find { |s| s.code.upcase == code.upcase }

          return state if state
        end
        nil
      end
    end

    def find_by_name(name, country: nil)
      return nil if name.blank?

      if country
        for_country(country).find { |state| state.name.downcase == name.downcase }
      else
        SUPPORTED_COUNTRIES.each do |country_code|
          country = Country.find(country_code)
          state = for_country(country).find { |s| s.name.downcase == name.downcase }

          return state if state
        end
        nil
      end
    end

    def all
      @all ||= SUPPORTED_COUNTRIES.flat_map { |code| for_country(Country.find(code)) }
    end

    def for_country(country)
      return [] if country.blank?

      case country.alpha2
      when "US"
        us_states
      when "GB"
        uk_nations
      when "AU"
        au_states
      when "CA"
        ca_provinces
      else
        []
      end
    end

    def us_states
      @us_states ||= begin
        us_country = Country.find("US")

        ISO3166::Country.new("US").subdivisions.map do |code, data|
          new(code: code, name: data["name"], country: us_country)
        end.sort_by(&:name)
      end
    end

    def us_state_abbreviations
      @us_state_abbreviations ||= us_states.to_h { |state| [state.name, state.code] }
    end

    def uk_nations
      @uk_nations ||= begin
        uk_country = Country.find("GB")

        ISO3166::Country.new("GB").subdivisions
          .slice(*UK_NATIONS)
          .map { |code, data| new(code: code, name: data["name"], country: uk_country) }
          .sort_by(&:name)
      end
    end

    def au_states
      @au_states ||= begin
        au_country = Country.find("AU")

        ISO3166::Country.new("AU").subdivisions.map do |code, data|
          new(code: code, name: data["name"], country: au_country)
        end.sort_by(&:name)
      end
    end

    def au_state_abbreviations
      @au_state_abbreviations ||= au_states.to_h { |state| [state.name, state.code] }
    end

    def ca_provinces
      @ca_provinces ||= begin
        ca_country = Country.find("CA")

        ISO3166::Country.new("CA").subdivisions.map do |code, data|
          new(code: code, name: data["name"], country: ca_country)
        end.sort_by(&:name)
      end
    end

    def ca_province_abbreviations
      @ca_province_abbreviations ||= ca_provinces.to_h { |state| [state.name, state.code] }
    end

    def select_options(country: nil)
      for_country(country).map { |state| [state.name, state.code] }
    end
  end
end
