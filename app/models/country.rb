class Country
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

  class << self
    def find(term)
      term = term.to_s.tr("-", " ")

      return nil if term.blank?
      return nil if term.downcase.in?(%w[online earth unknown])

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
      return ISO3166::Country.new("US") if ISO3166::Country.new("US").subdivisions.key?(term)

      return ISO3166::Country.new("GB") if term.in?(%w[UK Scotland])

      ISO3166::Country.find_country_by_iso_short_name(term) ||
        ISO3166::Country.find_country_by_unofficial_names(term) ||
        ISO3166::Country.search(term)
    end
  end
end
