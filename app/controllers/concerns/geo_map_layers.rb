# frozen_string_literal: true

module GeoMapLayers
  extend ActiveSupport::Concern

  private

  def build_sidebar_geo_layers(events, include_broader_scope: true)
    layers = []
    city_pin = build_city_pin(@location)

    layers << build_layer(
      id: "geo-location",
      label: @location.name,
      emoji: "📍",
      events: events,
      bounds: @location.bounds,
      city_pin: city_pin,
      always_visible: true
    )

    return layers unless include_broader_scope

    add_broader_layers(layers, events)
    set_first_visible_layer(layers)

    layers
  end

  def add_broader_layers(layers, current_events)
    case @location
    when City
      add_nearby_layer(layers, current_events)
      add_state_layer(layers)
      add_country_layer(layers)
      add_continent_layer(layers)
    when State
      add_country_layer(layers)
      add_continent_layer(layers)
    when Country, UKNation
      add_continent_layer(layers)
    end
  end

  def add_nearby_layer(layers, city_events)
    return unless @city.respond_to?(:nearby_events) && @city.geocoded?

    nearby_event_data = @city.nearby_events(radius_km: 250, limit: 50, exclude_ids: city_events.map(&:id))
    nearby_events_list = filter_events_by_time(nearby_event_data.map { |d| d[:event] })

    maybe_add_layer(layers, id: "geo-nearby", label: "Nearby", emoji: "📍🔄", events: city_events + nearby_events_list)
  end

  def add_state_layer(layers)
    return unless @state.present? && @country.present? && @country&.states?

    maybe_add_layer(layers, id: "geo-state", label: @state.name, emoji: "🗺️", events: @state.events.includes(:series))
  end

  def add_country_layer(layers)
    return unless @country.present?

    maybe_add_layer(layers, id: "geo-country", label: @country.name, emoji: @country.emoji_flag, events: @country.events.includes(:series))
  end

  def add_continent_layer(layers)
    return unless @continent.present?

    maybe_add_layer(layers, id: "geo-continent", label: @continent.name, emoji: @continent.emoji_flag, events: @continent.events.includes(:series))
  end

  def maybe_add_layer(layers, id:, label:, emoji:, events:)
    current_marker_count = layers.last&.dig(:markers)&.size || 0
    markers = event_map_markers(filter_events_by_time(events.to_a).select(&:geocoded?))

    return unless markers.any? && markers.size > current_marker_count

    layers << build_layer(id: id, label: label, emoji: emoji, markers: markers)
  end

  def build_layer(id:, label:, emoji:, events: nil, markers: nil, bounds: nil, city_pin: nil, always_visible: false)
    {
      id: id,
      label: label,
      emoji: emoji,
      markers: markers || event_map_markers(events.to_a.select(&:geocoded?)),
      bounds: bounds,
      cityPin: city_pin,
      visible: false,
      alwaysVisible: always_visible.presence,
      group: "geo"
    }.compact
  end

  def build_city_pin(location)
    return unless location.respond_to?(:geocoded?) && location.geocoded?

    {type: "city", name: location.name, longitude: location.longitude, latitude: location.latitude}
  end

  def set_first_visible_layer(layers)
    first_with_markers = layers.find { |l| l[:markers].any? }

    if first_with_markers
      first_with_markers[:visible] = true
    elsif layers.any?
      layers.first[:visible] = true
    end
  end

  def filter_events_by_time(events)
    events
  end
end
