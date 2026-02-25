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
      city_record = ::City.find_by(slug: slug)
      city_record ||= ::City.find_by(name: name, state_code: state_code, country_code: country_code)
      city_record ||= find_by_yaml_aliases
      city_record ||= ::City.new

      city_record.assign_attributes(
        name: name,
        state_code: state_code,
        country_code: country_code,
        latitude: latitude,
        longitude: longitude,
        featured: true,
        slug: slug
      )

      begin
        city_record.save!
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error("Failed to import city #{name} (#{slug}): #{e.message}")
        raise e
      end

      city_record.sync_aliases_from_list(aliases) if aliases.present?

      Search::Backend.index(city_record) if index

      city_record
    end

    private

    def find_by_yaml_aliases
      return nil if aliases.blank?

      aliases.each do |alias_name|
        city = ::City.where(country_code: country_code).where("LOWER(name) = ?", alias_name.downcase).first

        return city if city

        city = ::City.find_by_alias(alias_name, country_code: country_code)

        return city if city
      end

      nil
    end
  end
end
