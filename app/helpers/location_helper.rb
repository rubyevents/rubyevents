# frozen_string_literal: true

module LocationHelper
  def location_path(location)
    location.path
  end

  def location_past_path(location)
    case location
    when OnlineLocation
      online_past_index_path
    when Continent
      continent_past_index_path(location)
    when Country, UKNation
      country_past_index_path(location)
    when State
      state_past_index_path(state_alpha2: location.country.code, state_slug: location.slug)
    when FeaturedCity
      city_past_index_path(location)
    when City
      city_past_path_for(location)
    else
      "#past"
    end
  end

  def location_users_path(location)
    case location
    when OnlineLocation
      nil
    when Continent
      continent_users_path(location)
    when Country, UKNation
      country_users_path(location)
    when State
      state_users_path(state_alpha2: location.country.code, state_slug: location.slug)
    when FeaturedCity
      city_users_path(location)
    when City
      city_users_path_for(location)
    else
      "#rubyists"
    end
  end

  def location_countries_path(location)
    case location
    when Continent
      continent_countries_path(location)
    end
  end

  def location_cities_path(location)
    case location
    when Country, UKNation
      country_cities_path(location)
    when State
      state_cities_path(state_alpha2: location.country.code, state_slug: location.slug)
    end
  end

  def location_stamps_path(location)
    case location
    when Continent
      continent_stamps_path(location)
    when Country, UKNation
      country_stamps_path(location)
    when State
      state_stamps_path(state_alpha2: location.country.code, state_slug: location.slug)
    when FeaturedCity
      city_stamps_path(location)
    when City
      city_stamps_path_for(location)
    else
      "#stamps"
    end
  end

  def location_map_path(location)
    case location
    when OnlineLocation
      nil
    when Continent
      continent_map_index_path(location)
    when Country, UKNation
      country_map_index_path(location)
    when State
      state_map_index_path(state_alpha2: location.country.code, state_slug: location.slug)
    when FeaturedCity
      city_map_index_path(location)
    when City
      city_map_path_for(location)
    else
      "#map"
    end
  end

  def location_subtitle(location)
    case location
    when OnlineLocation
      "Virtual and remote events"
    when Continent
      location.name
    when Country, UKNation
      "#{location.name}, #{location.continent}"
    when State
      "#{location.name}, #{location.country.name}"
    when FeaturedCity, City
      location.location_string
    else
      location.name
    end
  end

  def location_has_routes?(location)
    location.is_a?(OnlineLocation) || location.is_a?(Continent) || location.is_a?(Country) || location.is_a?(UKNation) || location.is_a?(State) || location.is_a?(FeaturedCity) || location.is_a?(City)
  end

  private

  def city_past_path_for(city)
    if city.state_code.present? && city.state.present?
      city_with_state_past_index_path(alpha2: city.country_code.downcase, state: city.state.slug, city: city.slug)
    else
      city_by_country_past_index_path(alpha2: city.country_code.downcase, city: city.slug)
    end
  end

  def city_users_path_for(city)
    if city.state_code.present? && city.state.present?
      city_with_state_users_path(alpha2: city.country_code.downcase, state: city.state.slug, city: city.slug)
    else
      city_by_country_users_path(alpha2: city.country_code.downcase, city: city.slug)
    end
  end

  def city_stamps_path_for(city)
    if city.state_code.present? && city.state.present?
      city_with_state_stamps_path(alpha2: city.country_code.downcase, state: city.state.slug, city: city.slug)
    else
      city_by_country_stamps_path(alpha2: city.country_code.downcase, city: city.slug)
    end
  end

  def city_map_path_for(city)
    if city.state_code.present? && city.state.present?
      city_with_state_map_index_path(alpha2: city.country_code.downcase, state: city.state.slug, city: city.slug)
    else
      city_by_country_map_index_path(alpha2: city.country_code.downcase, city: city.slug)
    end
  end
end
