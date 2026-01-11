# frozen_string_literal: true

module LocationHelper
  def location_path(location)
    location.path
  end

  def location_past_path(location)
    location.past_path
  end

  def location_users_path(location)
    location.users_path
  end

  def location_countries_path(location)
    location.try(:countries_path)
  end

  def location_cities_path(location)
    location.try(:cities_path)
  end

  def location_stamps_path(location)
    location.stamps_path
  end

  def location_map_path(location)
    location.map_path
  end

  def location_subtitle(location)
    location.subtitle
  end

  def location_has_routes?(location)
    location.has_routes?
  end
end
