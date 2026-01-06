class User::LocationInfo < ActiveRecord::AssociatedObject
  def country
    @country ||= if user.country_code.present?
      Country.find_by(country_code: user.country_code)
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

  def to_s
    user.location
  end

  def present?
    user.location.present?
  end

  def link_path
    country&.path
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
