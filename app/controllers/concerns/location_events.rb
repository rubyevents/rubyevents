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
    return [] unless @country.present?

    scope = @country.events.includes(:series).upcoming
    scope = scope.where.not(city: @location.name) if @location.is_a?(City)
    scope = scope.where.not(id: exclude_ids) if exclude_ids.any?
    scope
  end

  def continent_upcoming_events(exclude_country_codes: [])
    return [] unless @continent.present?

    country_codes = @continent.country_codes - exclude_country_codes

    Event.includes(:series).where(country_code: country_codes).upcoming
  end
end
