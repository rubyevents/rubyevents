class UKNation
  attr_reader :slug, :state_code, :nation_name

  def initialize(slug)
    @slug = slug
    data = Country::UK_NATIONS[slug]
    @state_code = data[:code]
    @nation_name = data[:name]
  end

  def self.find_by_code(code)
    return nil if code.blank?

    code_upper = code.upcase

    nation_code = if code_upper.start_with?("GB-")
      code_upper.sub("GB-", "")
    else
      code_upper
    end

    slug = Country::UK_NATIONS.find { |_, data| data[:code] == nation_code }&.first
    slug ||= Country::UK_NATIONS.find { |_, data| data[:name].upcase == nation_code }&.first

    slug ? new(slug) : nil
  end

  def name
    nation_name
  end

  def alpha2
    "GB-#{state_code}"
  end

  def alpha3
    nil
  end

  def continent
    "Europe"
  end

  def emoji_flag
    "\u{1F1EC}\u{1F1E7}"
  end

  def path
    Router.country_path(slug)
  end

  def past_path
    Router.country_past_index_path(self)
  end

  def users_path
    Router.country_users_path(self)
  end

  def cities_path
    Router.country_cities_path(self)
  end

  def stamps_path
    Router.country_stamps_path(self)
  end

  def map_path
    Router.country_map_index_path(self)
  end

  def has_routes?
    true
  end

  def code
    "gb"
  end

  def country_code
    "GB"
  end

  def to_param
    slug
  end

  def ==(other)
    other.is_a?(UKNation) && slug == other.slug
  end

  def eql?(other)
    self == other
  end

  def hash
    slug.hash
  end

  def events
    Event.where(country_code: "GB", state_code: [state_code, nation_name])
  end

  def users
    User.indexable.geocoded.where(country_code: "GB", state_code: [state_code, nation_name])
  end

  def stamps
    Stamp.all.select { |stamp| stamp.code == alpha2 }
  end

  def bounds
    nil
  end

  def held_in_sentence
    " held in #{name}"
  end

  def uk_nation?
    true
  end

  def parent_country
    Country.find("GB")
  end

  def to_location
    Location.new(state_code: state_code, country_code: "GB", raw_location: "#{name}, Europe")
  end
end
