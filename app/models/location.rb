# frozen_string_literal: true

class Location
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::UrlHelper
  include ActionView::Context

  ONLINE_LOCATIONS = %w[online virtual remote].freeze

  attr_reader :city, :state_code, :country_code, :latitude, :longitude, :raw_location, :hybrid

  def initialize(city: nil, state_code: nil, country_code: nil, latitude: nil, longitude: nil, raw_location: nil, hybrid: false)
    @city = city
    @state_code = state_code
    @country_code = country_code
    @latitude = latitude
    @longitude = longitude
    @raw_location = raw_location
    @hybrid = hybrid
  end

  def self.from_record(record)
    new(
      city: record.try(:city),
      state_code: record.try(:state_code),
      country_code: record.try(:country_code) || record.try(:alpha2),
      latitude: record.try(:latitude),
      longitude: record.try(:longitude),
      raw_location: record.try(:location),
      hybrid: record.try(:static_metadata)&.try(:hybrid?) || false
    )
  end

  def self.from_string(location_string)
    new(raw_location: location_string)
  end

  def self.online
    new(raw_location: "online")
  end

  def city_object
    return nil if city.blank? || country.blank?

    @city_object ||= City.find_for(city: city, country_code: country.alpha2, state_code: state&.code) ||
      City.new(name: city, slug: city.parameterize, country_code: country.alpha2, state_code: state&.code)
  end

  def state
    return nil unless country&.states? && state_code.present?

    @state ||= State.find_by_code(state_code, country: country) || State.find_by_name(state_code, country: country)
  end

  def country
    return nil if country_code.blank?

    @country ||= Country.find_by(country_code: country_code)
  end

  def city_path
    city_object&.path
  end

  def state_path
    state&.path
  end

  def country_path
    country&.path
  end

  def continent
    country&.continent
  end

  def continent_name
    continent&.name
  end

  def continent_path
    continent&.path
  end

  def online_location
    @online_location ||= OnlineLocation.instance
  end

  def online_path
    online_location.path
  end

  def online?
    return false if geocoded?

    raw_location.to_s.downcase.in?(ONLINE_LOCATIONS)
  end

  def hybrid?
    !!hybrid
  end

  def state_display_name
    state&.display_name || state_code
  end

  def display_city
    base = city.presence&.strip

    return state_display_name if base.blank? && state
    return base unless country&.states? && state_code.present?
    return state_display_name if base&.downcase == state_display_name&.downcase

    "#{base}, #{state_display_name}"
  end

  def geocoded?
    latitude.present? && longitude.present?
  end

  def present?
    raw_location.present? || city.present? || country_code.present?
  end

  def blank?
    !present?
  end

  def has_state?
    state_path.present?
  end

  def has_city?
    city.present? && country.present?
  end

  def to_s
    raw_location || [display_city, country&.name].compact.join(", ")
  end

  # Renders location as HTML with optional links
  #
  # Examples:
  #   to_html                              # => "Portland, OR, United States" with links
  #   to_html(show_links: false)           # => "Portland, OR, United States" as text
  #   to_html(upto: :city)                 # => "Portland, OR" with link
  #   to_html(upto: :continent)            # => "Portland, OR, United States, North America"
  def to_html(show_links: true, link_class: "link", upto: :country)
    return "".html_safe if blank?
    return render_online(show_links: show_links, link_class: link_class) if online?
    return content_tag(:span, to_s) unless geocoded?

    result = render_upto(upto: upto, show_links: show_links, link_class: link_class)
    result = append_hybrid_html(result, show_links: show_links, link_class: link_class) if hybrid?
    result
  end

  def to_text(upto: :country)
    return "" if blank?
    return online_location.name if online?

    result = text_upto(upto)
    result = raw_location if result.blank? && raw_location.present?
    result = "#{result} & online" if hybrid? && result.present?

    result.to_s
  end

  private

  LEVEL_ORDER = [:city, :state, :country, :continent].freeze

  def text_upto(upto)
    location_parts(upto: upto).map { |part| part[:text] }.compact.join(", ")
  end

  def render_online(show_links:, link_class:)
    link_or_text(online_location.name, online_path, show_links: show_links, link_class: link_class)
  end

  def render_upto(upto:, show_links:, link_class:)
    parts = location_parts(upto: upto).map do |part|
      link_or_text(part[:text], part[:path], show_links: show_links, link_class: link_class)
    end

    join_parts(parts, ", ")
  end

  def location_parts(upto:)
    includes = ->(level) { LEVEL_ORDER.index(upto).to_i >= LEVEL_ORDER.index(level) }
    parts = []

    if includes[:state] && has_state?
      parts << {text: city, path: city_path} if city.present?
      parts << {text: state_display_name, path: state_path}
    elsif display_city.present?
      parts << {text: display_city, path: city_path}
    end

    parts << {text: country.name, path: country_path} if includes[:country] && country.present?
    parts << {text: continent_name, path: continent_path} if includes[:continent] && continent.present?

    parts
  end

  def append_hybrid_html(result, show_links:, link_class:)
    online_part = link_or_text("online", online_path, show_links: show_links, link_class: link_class)

    "#{result} & #{online_part}".html_safe
  end

  def link_or_text(text, path, show_links:, link_class:)
    return content_tag(:span, text) if text.blank?

    if show_links && path
      link_to(text, path, class: link_class)
    else
      content_tag(:span, text)
    end
  end

  def join_parts(parts, separator)
    parts.compact.map(&:to_s).join(separator).html_safe
  end
end
