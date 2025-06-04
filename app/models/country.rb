class Country
  def self.find(term)
    term = term.tr("-", " ")

    return nil if term.blank?
    return nil if term.downcase == "online"
    return nil if term.downcase == "earth"
    return nil if term.downcase == "unknown"

    return ISO3166::Country.new("US") if ISO3166::Country.new("US").subdivisions.key?(term)
    return ISO3166::Country.new("GB") if term == "UK"
    return ISO3166::Country.new("GB") if term == "Scotland"

    country = ISO3166::Country.find_country_by_iso_short_name(term) if country.nil?
    country = ISO3166::Country.find_country_by_unofficial_names(term) if country.nil?
    country = ISO3166::Country.search(term) if country.nil?

    country
  end

  def self.all
    @all ||= ISO3166::Country.all.to_h { |country| [country.iso_short_name.parameterize, country] }
  end

  def self.slugs
    all.keys
  end
end
