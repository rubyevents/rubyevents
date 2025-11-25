class User::LocationInfo < ActiveRecord::AssociatedObject
  def country
    @country ||= find_country_from_string(user.location)
  end

  def country_code
    country&.alpha2
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
