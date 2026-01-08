class Country
  include Locatable

  UK_NATIONS = {
    "england" => {code: "ENG", name: "England"},
    "scotland" => {code: "SCT", name: "Scotland"},
    "wales" => {code: "WLS", name: "Wales"},
    "northern-ireland" => {code: "NIR", name: "Northern Ireland"}
  }.freeze

  attr_reader :record

  delegate :alpha2, :alpha3, :continent, :emoji_flag, :subdivisions, :iso_short_name, :common_name, :translations, to: :record

  def initialize(record)
    @record = record
  end

  def name
    record.translations["en"] || record.common_name || record.iso_short_name
  end

  def slug
    name.parameterize
  end

  def path
    "/countries/#{slug}"
  end

  def code
    alpha2.downcase
  end

  def latitude
    record.geo&.dig("latitude")
  end

  def longitude
    record.geo&.dig("longitude")
  end

  def coordinates
    return nil unless latitude && longitude
    [longitude, latitude]
  end

  def bounds
    geo_bounds = record.geo&.dig("bounds")
    return nil unless geo_bounds

    {
      southwest: [geo_bounds.dig("southwest", "lng"), geo_bounds.dig("southwest", "lat")],
      northeast: [geo_bounds.dig("northeast", "lng"), geo_bounds.dig("northeast", "lat")]
    }
  end

  def to_param
    slug
  end

  def ==(other)
    other.is_a?(Country) && alpha2 == other.alpha2
  end

  def eql?(other)
    self == other
  end

  def hash
    alpha2.hash
  end

  def events
    Event.where(country_code: alpha2)
  end

  def users
    User.where(country_code: alpha2)
  end

  def stamps
    Stamp.all.select { |stamp| stamp.has_country? && stamp.country&.alpha2 == alpha2 }
  end

  def held_in_sentence
    if name.starts_with?("United")
      " held in the #{name}"
    else
      " held in #{name}"
    end
  end

  def uk_nation?
    false
  end

  class << self
    def find(term)
      term = term.to_s.tr("-", " ")
      term_slug = term.parameterize

      return nil if term.blank?
      return nil if term.downcase.in?(%w[online earth unknown])

      if UK_NATIONS.key?(term_slug)
        return UKNation.new(term_slug)
      end

      iso_record = find_iso_record(term)
      iso_record ? new(iso_record) : nil
    end

    def find_by(country_code:)
      return nil if country_code.blank?

      iso_record = ISO3166::Country.new(country_code.upcase)
      iso_record&.alpha2 ? new(iso_record) : nil
    end

    def all
      @all ||= ISO3166::Country.all.map { |iso_record| new(iso_record) }
    end

    def all_with_uk_nations
      @all_with_uk_nations ||= all + uk_nations
    end

    def uk_nations
      UK_NATIONS.keys.map { |slug| UKNation.new(slug) }
    end

    def valid_country_codes
      @valid_country_codes ||= ISO3166::Country.codes
    end

    def all_by_slug
      @all_by_slug ||= all.index_by(&:slug)
    end

    def slugs
      all.map(&:slug)
    end

    def select_options
      all.map { |country| [country.name, country.alpha2] }.sort_by(&:first)
    end

    def search(query)
      return nil if query.blank?

      results = Geocoder.search(query)
      return nil if results.empty?

      country_code = results.first.country_code
      return nil if country_code.blank?

      find_by(country_code: country_code)
    end

    private

    def find_iso_record(term)
      return ISO3166::Country.new("GB") if term == "UK"

      if term.length == 2
        country = ISO3166::Country.new(term.upcase)
        return country if country&.alpha2
      end

      result = ISO3166::Country.find_country_by_iso_short_name(term) ||
        ISO3166::Country.find_country_by_unofficial_names(term) ||
        ISO3166::Country.search(term)

      return result if result

      return ISO3166::Country.new("US") if ISO3166::Country.new("US").subdivisions.key?(term)

      nil
    end
  end
end
