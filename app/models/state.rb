class State
  EXCLUDED_COUNTRIES = ["PL"]
  SUPPORTED_COUNTRIES = (Country.all.select { |country| country.subdivisions.any? }.map(&:alpha2) - EXCLUDED_COUNTRIES).freeze
  UK_NATIONS = %w[ENG SCT WLS NIR].freeze

  attr_reader :country, :record

  def initialize(country:, record:)
    @country = country
    @record = record
  end

  def name
    record.translations.dig(:en) || record.name
  end

  def code
    record.code
  end

  def slug
    name.parameterize
  end

  def abbreviation
    code
  end

  def display_name
    if country.alpha2 == "GB" || code.match?(/^\d+$/)
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
    Location.new(state_code: code, country_code: country_code, raw_location: "#{name}, #{country.name}")
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

      country.subdivisions.map { |_, record|
        new(country: country, record: record)
      }
    end

    def select_options(country: nil)
      for_country(country).map { |state| [state.name, state.code] }
    end
  end
end
