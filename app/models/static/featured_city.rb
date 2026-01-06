module Static
  class FeaturedCity < FrozenRecord::Base
    self.backend = Backends::FileBackend.new("featured_cities.yml")
    self.base_path = Rails.root.join("data")

    def self.import_all!
      all.each(&:import!)
    end

    def import!
      ::FeaturedCity.find_or_create_by!(slug: slug) do |featured_city|
        featured_city.name = name
        featured_city.city = city
        featured_city.state_code = state_code
        featured_city.country_code = country_code
        featured_city.latitude = latitude
        featured_city.longitude = longitude
      end
    end
  end
end
