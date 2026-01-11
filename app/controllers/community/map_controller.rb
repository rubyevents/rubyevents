# frozen_string_literal: true

class Community::MapController < ApplicationController
  include UserMapMarkers

  skip_before_action :authenticate_user!

  def index
    @users = User.canonical.geocoded.preloaded
    @geo_layers = build_geographic_layers
    @user_count = @users.count
  end

  private

  def build_geographic_layers
    layers = []

    users_by_continent = @users.group_by { |u| Country.find_by(country_code: u.country_code)&.continent }

    users_by_continent.each do |continent, users|
      next unless continent

      markers = user_map_markers(users)
      next if markers.empty?

      layers << {
        id: "geo-#{continent.slug}",
        label: continent.name,
        emoji: continent.emoji_flag,
        markers: markers,
        visible: false,
        group: "geo"
      }
    end

    layers = layers.sort_by { |l| -l[:markers].size }

    select_default_visible_layer(layers)
  end

  def select_default_visible_layer(layers)
    return layers if layers.empty?

    layers.each { |layer| layer[:visible] = false }

    largest_layer = layers.max_by { |layer| layer[:markers].sum { |m| m[:users]&.size || 0 } }

    if largest_layer
      largest_layer[:visible] = true
    else
      layers.first[:visible] = true
    end

    layers
  end
end
