class User::LocationInfo < ActiveRecord::AssociatedObject
  def country
    @country ||= if user.country_code.present?
      Country.find(user.country_code)
    else
      find_country_from_string(user.location)
    end
  end

  def country_code
    user.country_code.presence || country&.alpha2
  end

  def city
    user.city
  end

  def state
    user.state
  end

  def latitude
    user.latitude
  end

  def longitude
    user.longitude
  end

  def geocoded?
    user.latitude.present? && user.longitude.present?
  end

  def country_name
    country&.iso_short_name
  end

  def to_s
    user.location
  end

  def present?
    user.location.present?
  end

  def link_path
    return nil unless country.present?

    "/countries/#{country.translations["en"].parameterize}"
  end

  private

  def find_country_from_string(location_string)
    return nil if location_string.blank?

    country = Country.find(location_string)

    return country if country.present?

    location_string.split(",").each do |part|
      country = Country.find(part.strip)

      return country if country.present?
    end

    nil
  end
end
