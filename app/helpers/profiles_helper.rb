module ProfilesHelper
  def find_country_from_location(location)
    return nil if location.blank?

    country = Country.find(location)

    return country if country.present?

    location.split(",").each do |part|
      country = Country.find(part.strip)

      return country if country.present?
    end

    nil
  end
end
