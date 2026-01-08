# frozen_string_literal: true

module GeoMapLayers
  extend ActiveSupport::Concern

  private

  def build_sidebar_geo_layers(events, include_broader_scope: true)
    layers = []

    location_markers = event_map_markers(events.to_a.select(&:geocoded?))

    city_pin = nil

    if @location.respond_to?(:geocoded?) && @location.geocoded?
      city_pin = {
        type: "city",
        name: @location.name,
        longitude: @location.longitude,
        latitude: @location.latitude
      }
    end

    layers << {
      id: "geo-location",
      label: @location.name,
      emoji: "📍",
      markers: location_markers,
      bounds: @location.bounds,
      cityPin: city_pin,
      visible: false,
      alwaysVisible: true,
      group: "geo"
    }

    return layers unless include_broader_scope

    case @location
    when FeaturedCity, City
      add_city_broader_layers(layers, events)
    when State
      add_state_broader_layers(layers, events)
    when Country, UKNation
      add_country_broader_layers(layers, events)
    end

    first_with_markers = layers.find { |l| l[:markers].any? }

    if first_with_markers
      first_with_markers[:visible] = true
    elsif layers.any?
      layers.first[:visible] = true
    end

    layers
  end

  def add_city_broader_layers(layers, city_events)
    city_event_ids = city_events.map(&:id)
    current_marker_count = layers.last&.dig(:markers)&.size || 0

    if @city.respond_to?(:nearby_events) && @city.geocoded?
      nearby_event_data = @city.nearby_events(radius_km: 250, limit: 50, exclude_ids: city_event_ids)
      nearby_events_list = filter_events_by_time(nearby_event_data.map { |d| d[:event] })

      city_plus_nearby = city_events + nearby_events_list
      nearby_markers = event_map_markers(city_plus_nearby.select(&:geocoded?))

      if nearby_markers.any? && nearby_markers.size > current_marker_count
        layers << {
          id: "geo-nearby",
          label: "Nearby",
          emoji: "📍🔄",
          markers: nearby_markers,
          visible: false,
          group: "geo"
        }

        current_marker_count = nearby_markers.size
      end
    end

    if @state.present? && @country.present? && State.supported_country?(@country)
      state_events = filter_events_by_time(
        Event.includes(:series)
          .where(country_code: @country.alpha2, state: @state.code)
          .to_a
      )

      state_markers = event_map_markers(state_events.select(&:geocoded?))

      if state_markers.any? && state_markers.size > current_marker_count
        layers << {
          id: "geo-state",
          label: @state.name,
          emoji: "🗺️",
          markers: state_markers,
          visible: false,
          group: "geo"
        }

        current_marker_count = state_markers.size
      end
    end

    if @country.present?
      country_events = filter_events_by_time(
        Event.includes(:series)
          .where(country_code: @country.alpha2)
          .to_a
      )

      country_markers = event_map_markers(country_events.select(&:geocoded?))

      if country_markers.any? && country_markers.size > current_marker_count
        layers << {
          id: "geo-country",
          label: @country.name,
          emoji: @country.emoji_flag,
          markers: country_markers,
          visible: false,
          group: "geo"
        }

        current_marker_count = country_markers.size
      end
    end

    add_continent_layer(layers, current_marker_count)
  end

  def add_state_broader_layers(layers, state_events)
    current_marker_count = layers.last&.dig(:markers)&.size || 0

    if @country.present?
      country_events = filter_events_by_time(
        Event.includes(:series)
          .where(country_code: @country.alpha2)
          .to_a
      )

      country_markers = event_map_markers(country_events.select(&:geocoded?))

      if country_markers.any? && country_markers.size > current_marker_count
        layers << {
          id: "geo-country",
          label: @country.name,
          emoji: @country.emoji_flag,
          markers: country_markers,
          visible: false,
          group: "geo"
        }
        current_marker_count = country_markers.size
      end
    end

    add_continent_layer(layers, current_marker_count)
  end

  def add_country_broader_layers(layers, country_events)
    current_marker_count = layers.last&.dig(:markers)&.size || 0

    add_continent_layer(layers, current_marker_count)
  end

  def add_continent_layer(layers, current_marker_count)
    return unless @continent.present?

    continent_country_codes = @continent.countries.map(&:alpha2)
    continent_events = filter_events_by_time(
      Event.includes(:series).where(country_code: continent_country_codes).to_a
    )
    continent_markers = event_map_markers(continent_events.select(&:geocoded?))

    if continent_markers.any? && continent_markers.size > current_marker_count
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

  def filter_events_by_time(events)
    events
  end
end
