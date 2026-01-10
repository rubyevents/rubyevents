# frozen_string_literal: true

module Static
  class City < FrozenRecord::Base
    self.backend = Backends::FileBackend.new("featured_cities.yml")
    self.base_path = Rails.root.join("data")

    SEARCH_INDEX_ON_IMPORT_DEFAULT = ENV.fetch("SEARCH_INDEX_ON_IMPORT", "true") == "true"

    def self.import_all!(index: SEARCH_INDEX_ON_IMPORT_DEFAULT)
      all.map { |city| city.import!(index: index) }
    end

    def import!(index: SEARCH_INDEX_ON_IMPORT_DEFAULT)
      city_record = ::City.find_or_initialize_by(slug: slug)

      city_record.assign_attributes(
        name: name,
        state_code: state_code,
        country_code: country_code,
        latitude: latitude,
        longitude: longitude,
        featured: true
      )

      city_record.save!

      Search::Backend.index(city_record) if index

      city_record
    end
  end
end
