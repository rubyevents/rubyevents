# frozen_string_literal: true

module LocationInfoMethods
  extend ActiveSupport::Concern

  def city_path
    return nil if city.blank? || country.blank?

    featured = FeaturedCity.find_for(city: city, country_code: country.alpha2, state_code: state_object&.code)
    return featured.path if featured

    if State.supported_country?(country) && state.present?
      state_obj = state_object

      if state_obj
        "/cities/#{country.code}/#{state_obj.slug}/#{city.parameterize}"
      else
        "/cities/#{country.code}/#{city.parameterize}"
      end
    else
      "/cities/#{country.code}/#{city.parameterize}"
    end
  end

  def state_path
    return nil unless state.present?

    state_obj = state_object
    return nil unless state_obj

    case country&.alpha2
    when "US", "AU", "CA"
      "/states/#{country.code}/#{state_obj.slug}"
    when "GB"
      "/countries/#{state_obj.slug}"
    else
      state_obj.path
    end
  end

  def state_object
    return nil unless State.supported_country?(country) && state.present?

    State.find_by_code(state, country: country) || State.find_by_name(state, country: country)
  end

  def display_city
    base_city = (city.presence || location_without_country)&.strip

    if State.supported_country?(country) && state.present?
      display_state = state_display_name

      if base_city.blank?
        display_state
      elsif base_city.downcase == display_state&.downcase
        display_state
      else
        "#{base_city}, #{display_state}"
      end
    else
      return nil if base_city.present? && country.present? && base_city.downcase == country.name.downcase

      base_city
    end
  end

  def state_display_name
    return nil if state.blank? || country.blank?

    case country.alpha2
    when "US", "AU", "CA"
      state_abbreviation
    when "GB"
      state_obj = State.find_by_code(state, country: country) || State.find_by_name(state, country: country)
      state_obj&.name || state
    else
      state
    end
  end

  def state_abbreviation
    return nil if state.blank?

    abbreviations = case country&.alpha2
    when "US" then State.us_state_abbreviations
    when "AU" then State.au_state_abbreviations
    when "CA" then State.ca_province_abbreviations
    else {}
    end

    abbreviations[state] || ((state.length <= 3) ? state.upcase : state)
  end

  def link_path
    country&.path
  end

  def geocoded?
    latitude.present? && longitude.present?
  end

  private

  def find_country_from_string(location_string)
    return nil if location_string.blank?

    found = Country.find(location_string)
    return found if found.present?

    location_string.split(",").each do |part|
      found = Country.find(part.strip)
      return found if found.present?
    end

    nil
  end
end
