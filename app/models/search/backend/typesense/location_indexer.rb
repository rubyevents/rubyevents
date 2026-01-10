# frozen_string_literal: true

class Search::Backend::Typesense
  class LocationIndexer
    COLLECTION_NAME = "locations"

    class << self
      def collection_schema
        {
          "name" => COLLECTION_NAME,
          "fields" => [
            {"name" => "id", "type" => "string"},
            {"name" => "type", "type" => "string", "facet" => true},
            {"name" => "name", "type" => "string"},
            {"name" => "slug", "type" => "string"},
            {"name" => "code", "type" => "string", "optional" => true},
            {"name" => "country_code", "type" => "string", "optional" => true, "facet" => true},
            {"name" => "country_name", "type" => "string", "optional" => true},
            {"name" => "continent", "type" => "string", "optional" => true, "facet" => true},
            {"name" => "emoji_flag", "type" => "string", "optional" => true},
            {"name" => "event_count", "type" => "int32"},
            {"name" => "user_count", "type" => "int32", "optional" => true},
            {"name" => "coordinates", "type" => "geopoint", "optional" => true}
          ],
          "default_sorting_field" => "event_count",
          "token_separators" => ["-", "_"],
          "enable_nested_fields" => false
        }
      end

      def client
        ::Typesense::Client.new(::Typesense.configuration)
      end

      def collection
        client.collections[COLLECTION_NAME]
      end

      def ensure_collection!
        collection.retrieve
      rescue ::Typesense::Error::ObjectNotFound
        client.collections.create(collection_schema)
      end

      def reindex_all
        drop_collection!
        ensure_collection!
        create_synonyms!

        index_online
        index_continents
        index_countries
        index_states
        index_uk_nations
        index_cities

        Rails.logger.info "Typesense: Indexed all locations"
      end

      def create_synonyms!
        all_synonyms = city_synonyms.merge(online_synonyms)

        all_synonyms.each do |id, config|
          collection.synonyms.upsert(id, config)
        end

        Rails.logger.info "Typesense: Created #{all_synonyms.size} location synonyms"
      rescue => e
        Rails.logger.warn "Typesense: Failed to create synonyms: #{e.message}"
      end

      def city_synonyms
        Static::FeaturedCity.all.each_with_object({}) do |city, synonyms|
          next if city.aliases.blank?

          all_names = [city.name.downcase, city.slug] + Array(city.aliases).map(&:downcase)
          synonyms["#{city.slug}-synonym"] = {"synonyms" => all_names.uniq}
        end
      end

      def online_synonyms
        {
          "online-synonym" => {
            "synonyms" => %w[online virtual remote]
          }
        }
      end

      def drop_collection!
        collection.delete
      rescue ::Typesense::Error::ObjectNotFound
        # Collection doesn't exist, nothing to delete
      end

      def index_continents
        documents = build_continent_documents
        return if documents.empty?

        collection.documents.import(documents, action: "upsert")
        Rails.logger.info "Typesense: Indexed #{documents.size} continents"
      end

      def index_countries
        documents = build_country_documents
        return if documents.empty?

        collection.documents.import(documents, action: "upsert")
        Rails.logger.info "Typesense: Indexed #{documents.size} countries"
      end

      def index_states
        documents = build_state_documents
        return if documents.empty?

        collection.documents.import(documents, action: "upsert")
        Rails.logger.info "Typesense: Indexed #{documents.size} states"
      end

      def index_uk_nations
        documents = build_uk_nation_documents
        return if documents.empty?

        collection.documents.import(documents, action: "upsert")
        Rails.logger.info "Typesense: Indexed #{documents.size} UK nations"
      end

      def index_cities
        documents = build_city_documents
        return if documents.empty?

        collection.documents.import(documents, action: "upsert")
        Rails.logger.info "Typesense: Indexed #{documents.size} cities"
      end

      def index_online
        document = build_online_document
        return if document.nil?

        collection.documents.import([document], action: "upsert")
        Rails.logger.info "Typesense: Indexed online location"
      end

      def search(query, type: nil, limit: 10)
        ensure_collection!

        search_params = {
          q: query.presence || "*",
          query_by: "name,slug,code,country_name",
          per_page: limit,
          sort_by: "_text_match:desc,event_count:desc"
        }

        search_params[:filter_by] = "type:=#{type}" if type.present?

        result = collection.documents.search(search_params)

        documents = result["hits"].map { |hit| hit["document"].symbolize_keys }
        total = result["found"]

        [documents, total]
      end

      private

      def build_online_document
        event_count = Event.not_geocoded.count

        return nil if event_count.zero?

        {
          id: "online",
          type: "online",
          name: "Online",
          slug: "online",
          emoji_flag: "🌐",
          event_count: event_count
        }
      end

      def build_continent_documents
        continent_counts = Hash.new(0)

        countries_with_events.each do |country_code, event_count|
          country = Country.find_by(country_code: country_code)
          next unless country

          continent = Continent.find_by_name(country.continent)
          next unless continent

          continent_counts[continent.slug] += event_count
        end

        continent_counts.map do |slug, event_count|
          continent = Continent.find(slug)
          next unless continent

          {
            id: "continent_#{slug}",
            type: "continent",
            name: continent.name,
            slug: continent.slug,
            emoji_flag: continent.emoji_flag,
            event_count: event_count,
            coordinates: normalize_coordinates(continent.respond_to?(:to_coordinates) ? continent.to_coordinates : nil)
          }.compact
        end.compact
      end

      def build_country_documents
        countries_with_events.map do |country_code, event_count|
          country = Country.find_by(country_code: country_code)
          next unless country

          country_name = country.common_name || country.iso_short_name

          {
            id: "country_#{country_code}",
            type: "country",
            name: country_name,
            slug: country.slug,
            code: country_code,
            country_code: country_code,
            continent: country.continent,
            emoji_flag: country.emoji_flag,
            event_count: event_count,
            coordinates: normalize_coordinates(country.respond_to?(:to_coordinates) ? country.to_coordinates : nil)
          }.compact
        end.compact
      end

      def build_state_documents
        documents = []
        event_counts = states_with_events
        user_counts = states_with_users

        State::SUPPORTED_COUNTRIES.each do |country_code|
          country = Country.find_by(country_code: country_code)
          next unless country
          next if country_code == "GB" # UK nations handled separately

          State.all(country: country).each do |state|
            event_count = event_counts[[country_code, state.code]] || 0
            user_count = user_counts[[country_code, state.code]] || 0

            documents << {
              id: "state_#{country_code}_#{state.code}",
              type: "state",
              name: state.name,
              slug: state.slug,
              code: state.code,
              country_code: country_code,
              country_name: country.common_name || country.iso_short_name,
              emoji_flag: country.emoji_flag,
              event_count: event_count,
              user_count: user_count,
              coordinates: coordinates_for_state(country_code, state.code)
            }.compact
          end
        end

        documents
      end

      def build_uk_nation_documents
        documents = []
        uk_country = Country.find_by(country_code: "GB")

        Country::UK_NATIONS.each do |slug, data|
          UKNation.new(slug)

          event_count = Event.where(country_code: "GB")
            .where("city IN (?)", uk_nation_cities(data[:code]))
            .count

          user_count = User.indexable.where(country_code: "GB")
            .where("city IN (?)", uk_nation_cities(data[:code]))
            .count

          documents << {
            id: "uk_nation_#{data[:code]}",
            type: "uk_nation",
            name: data[:name],
            slug: slug,
            code: data[:code],
            country_code: "GB",
            country_name: "United Kingdom",
            emoji_flag: uk_country&.emoji_flag || "🇬🇧",
            event_count: event_count,
            user_count: user_count,
            coordinates: coordinates_for_uk_nation(data[:code])
          }.compact
        end

        documents
      end

      def uk_nation_cities(nation_code)
        # Map of major cities to UK nations
        cities_by_nation = {
          "ENG" => %w[London Birmingham Manchester Liverpool Leeds Sheffield Bristol Newcastle Nottingham Leicester Cambridge Oxford Bath Brighton Plymouth Reading],
          "SCT" => %w[Edinburgh Glasgow Aberdeen Dundee Inverness Stirling Perth],
          "WLS" => %w[Cardiff Swansea Newport Wrexham Barry],
          "NIR" => %w[Belfast Derry Lisburn Newry Bangor]
        }

        cities_by_nation[nation_code] || []
      end

      def build_city_documents
        City.all.map do |city|
          country = city.country
          country_name = country&.common_name || country&.iso_short_name || city.country_code

          {
            id: "city_#{city.country_code}_#{city.slug}",
            type: "city",
            name: city.name,
            slug: city.slug,
            code: city.state_code,
            country_code: city.country_code,
            country_name: country_name,
            emoji_flag: country&.emoji_flag,
            event_count: city.events_count,
            user_count: city.users_count,
            coordinates: normalize_coordinates(city.coordinates)
          }.compact
        end
      end

      def normalize_coordinates(coords)
        return nil if coords.blank?
        return nil unless coords.is_a?(Array) && coords.size == 2

        [coords[0].to_f, coords[1].to_f]
      end

      def countries_with_events
        @countries_with_events ||= Event.where.not(country_code: [nil, ""])
          .group(:country_code)
          .count
      end

      def states_with_events
        @states_with_events ||= Event
          .where.not(state: [nil, ""])
          .where.not(country_code: [nil, ""])
          .where(country_code: State::SUPPORTED_COUNTRIES)
          .group(:country_code, :state)
          .count
      end

      def cities_with_countries
        @cities_with_countries ||= Event.where.not(city: [nil, ""])
          .where.not(country_code: [nil, ""])
          .group(:city, :country_code)
          .count
          .map { |(city, country_code), count| [city, country_code, count] }
      end

      def states_with_users
        @states_with_users ||= User.indexable
          .where.not(state: [nil, ""])
          .where.not(country_code: [nil, ""])
          .where(country_code: State::SUPPORTED_COUNTRIES)
          .group(:country_code, :state)
          .count
      end

      def coordinates_for_state(country_code, state_code)
        event = Event.where(country_code: country_code, state: state_code).geocoded.first
        return normalize_coordinates(event.to_coordinates) if event

        user = User.indexable.where(country_code: country_code, state: state_code).geocoded.first
        return normalize_coordinates(user.to_coordinates) if user

        nil
      end

      def coordinates_for_uk_nation(nation_code)
        cities = uk_nation_cities(nation_code)
        return nil if cities.empty?

        event = Event.where(country_code: "GB", city: cities).geocoded.first
        return normalize_coordinates(event.to_coordinates) if event

        nil
      end
    end
  end
end
