# frozen_string_literal: true

module Locatable
  extend ActiveSupport::Concern

  def location_type
    self.class.name.underscore.to_sym
  end

  def continent?
    is_a?(Continent)
  end

  def country?
    is_a?(Country)
  end

  def city?
    is_a?(City) || is_a?(FeaturedCity)
  end

  def state?
    is_a?(State)
  end

  def has_sub_locations?
    continent? || country? || state?
  end

  def sub_location_label
    return "Countries" if continent?
    return "Cities" if country? || state?
    nil
  end
end
