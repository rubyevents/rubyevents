# frozen_string_literal: true

class Locations::MapController < Locations::BaseController
  def index
    @geo_layers = build_geographic_layers
    @time_layers = build_time_filter_options
    @layers = @geo_layers
    @online_events = fetch_online_events

    render_location_view("map")
  end

  private

  def build_time_filter_options
    has_upcoming = @geo_layers.any? { |l| l[:markers].any? { |m| m[:events].any? { |e| e[:upcoming] } } }
    has_past = @geo_layers.any? { |l| l[:markers].any? { |m| m[:events].any? { |e| !e[:upcoming] } } }

    options = []

    options << {id: "upcoming", label: "Upcoming", visible: true} if has_upcoming
    options << {id: "past", label: "Past", visible: !has_upcoming} if has_past
    options << {id: "all", label: "All Events", visible: false} if has_upcoming && has_past

    options
  end

  def build_geographic_layers
    layers = case @location
    when Continent
      build_continent_geo_layers
    when Country, UKNation
      build_country_geo_layers
    when State
      build_state_geo_layers
    when City
      build_city_geo_layers
    else
      raise "#{@location.class} unexpected"
    end

    select_default_visible_layer(layers)
  end

  def select_default_visible_layer(layers)
    return layers if layers.empty?

    layers.each { |layer| layer[:visible] = false }

    layer_with_upcoming = layers.find do |layer|
      layer[:markers].any? { |marker| marker[:events].any? { |event| event[:upcoming] } }
    end

    if layer_with_upcoming
      layer_with_upcoming[:visible] = true
    else
      first_with_events = layers.find { |layer| layer[:markers].any? }

      if first_with_events
        first_with_events[:visible] = true
      else
        layers.first[:visible] = true
      end
    end

    layers
  end

  def build_continent_geo_layers
    layers = []

    events_by_country = @continent.events.includes(:series).group_by(&:country_code)

    events_by_country.each do |country_code, events|
      country = Country.find_by(country_code: country_code)
      next unless country

      markers = event_map_markers(events)
      next if markers.empty?

      layers << {
        id: "geo-#{country_code.downcase}",
        label: country.name,
        markers: markers,
        visible: false,
        group: "geo"
      }
    end

    layers.sort_by { |l| -l[:markers].size }
  end

  def build_country_geo_layers
    layers = []

    country_events = @location.events.includes(:series).to_a
    country_markers = event_map_markers(country_events)

    if country_markers.any?
      layers << {
        id: "geo-country",
        label: @location.name,
        markers: country_markers,
        visible: false,
        group: "geo"
      }
    end

    if @continent.present?
      continent_country_codes = @continent.countries.map(&:alpha2)
      continent_events = Event.includes(:series).where(country_code: continent_country_codes).to_a
      continent_markers = event_map_markers(continent_events)

      if continent_markers.any? && continent_markers.size > country_markers.size
        layers << {
          id: "geo-continent",
          label: @continent.name,
          markers: continent_markers,
          visible: false,
          group: "geo"
        }
      end
    end

    layers
  end

  def build_state_geo_layers
    layers = []

    state_events = @state.events.includes(:series).to_a
    state_markers = event_map_markers(state_events)

    if state_markers.any?
      layers << {
        id: "geo-state",
        label: @state.name,
        markers: state_markers,
        visible: false,
        group: "geo"
      }
    end

    country_events = Event.includes(:series).where(country_code: @country.alpha2).to_a
    country_markers = event_map_markers(country_events)

    if country_markers.any? && country_markers.size > state_markers.size
      layers << {
        id: "geo-country",
        label: @country.name,
        markers: country_markers,
        visible: false,
        group: "geo"
      }
    end

    if @continent.present?
      continent_country_codes = @continent.countries.map(&:alpha2)
      continent_events = Event.includes(:series).where(country_code: continent_country_codes).to_a
      continent_markers = event_map_markers(continent_events)

      if continent_markers.any? && continent_markers.size > country_markers.size
        layers << {
          id: "geo-continent",
          label: @continent.name,
          markers: continent_markers,
          visible: false,
          group: "geo"
        }
      end
    end

    layers
  end

  def build_city_geo_layers
    layers = []

    city_events = location_events.to_a
    city_markers = event_map_markers(city_events)
    city_pin = nil

    if @city.geocoded?
      city_pin = {
        type: "city",
        name: @city.name,
        longitude: @city.longitude,
        latitude: @city.latitude
      }
    end

    layers << {
      id: "geo-city",
      label: @city.name,
      emoji: "📍",
      markers: city_markers,
      cityPin: city_pin,
      alwaysVisible: true,
      visible: false,
      group: "geo"
    }

    if @city.respond_to?(:nearby_events) && @city.geocoded?
      nearby_event_data = @city.nearby_events(radius_km: 250, limit: 50, exclude_ids: city_events.map(&:id))
      nearby_events_list = nearby_event_data.map { |d| d[:event] }

      city_plus_nearby = city_events + nearby_events_list
      nearby_markers = event_map_markers(city_plus_nearby)

      if nearby_markers.any? && nearby_markers.size > city_markers.size
        layers << {
          id: "geo-nearby",
          label: "Nearby",
          emoji: "📍🔄",
          markers: nearby_markers,
          visible: false,
          group: "geo"
        }
      end
    end

    if @state.present? && @country.present? && @country&.states?
      state_events = Event.includes(:series)
        .where(country_code: @country.alpha2, state_code: @state.code)
        .to_a
      state_markers = event_map_markers(state_events)

      if state_markers.any? && state_markers.size > (layers.last&.dig(:markers)&.size || 0)
        layers << {
          id: "geo-state",
          label: @state.name,
          emoji: "🗺️",
          markers: state_markers,
          visible: false,
          group: "geo"
        }
      end
    end

    if @country.present?
      country_events = Event.includes(:series).where(country_code: @country.alpha2).to_a
      country_markers = event_map_markers(country_events)

      if country_markers.any? && country_markers.size > (layers.last&.dig(:markers)&.size || 0)
        layers << {
          id: "geo-country",
          label: @country.name,
          emoji: @country.emoji_flag,
          markers: country_markers,
          visible: false,
          group: "geo"
        }
      end
    end

    if @continent.present?
      continent_country_codes = @continent.countries.map(&:alpha2)
      continent_events = Event.includes(:series).where(country_code: continent_country_codes).to_a
      continent_markers = event_map_markers(continent_events)

      if continent_markers.any? && continent_markers.size > (layers.last&.dig(:markers)&.size || 0)
        layers << {
          id: "geo-continent",
          label: @continent.name,
          emoji: @continent.emoji_flag,
          markers: continent_markers,
          visible: false,
          group: "geo"
        }
      end
    end

    layers
  end

  def fetch_online_events
    base_scope = Event.includes(:series).not_geocoded.upcoming

    case @location
    when Continent
      base_scope.where(country_code: @continent.countries.map(&:alpha2))
    when Country, UKNation
      country_code = @location.respond_to?(:alpha2) ? @location.alpha2 : @location.country_code
      base_scope.where(country_code: country_code)
    when State
      base_scope.where(country_code: @country.alpha2, state_code: @state.code)
    else # City
      base_scope.where(city: @city.name)
    end
  end

  def redirect_path_helper
    :city_map_index_path
  end
end
