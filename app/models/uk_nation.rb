class UKNation
  attr_reader :slug, :state_code, :nation_name

  def initialize(slug)
    @slug = slug
    data = Country::UK_NATIONS[slug]
    @state_code = data[:code]
    @nation_name = data[:name]
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
    "/countries/#{slug}"
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
    Event.where(country_code: "GB", state: [state_code, nation_name])
  end

  def users
    User.where(country_code: "GB", state: [state_code, nation_name])
  end

  def stamps
    []
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
end
