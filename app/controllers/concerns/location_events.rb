# frozen_string_literal: true

module LocationEvents
  extend ActiveSupport::Concern

  private

  def location_events
    @location_events ||= @location.events.includes(:series).order(start_date: :desc)
  end

  def upcoming_events
    @upcoming_events ||= location_events.upcoming.reorder(start_date: :asc)
  end

  def past_events
    @past_events ||= location_events.past.reorder(end_date: :desc)
  end

  def country_upcoming_events(exclude_ids: [])
    return [] unless location_country_code.present?

    Event.includes(:series)
      .where(country_code: location_country_code)
      .where.not(city: location_city_name)
      .where.not(id: exclude_ids)
      .upcoming
  end

  def continent_upcoming_events(exclude_country_codes: [])
    return [] unless @continent.present?

    continent_country_codes = @continent.countries.map(&:alpha2) - exclude_country_codes

    Event.includes(:series).where(country_code: continent_country_codes).upcoming
  end

  def location_country_code
    case @location
    when FeaturedCity, City
      @location.country_code
    when Country
      @location.alpha2
    end
  end

  def location_city_name
    case @location
    when FeaturedCity
      @location.city
    when City
      @location.name
    end
  end
end
