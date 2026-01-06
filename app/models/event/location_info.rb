class Event::LocationInfo < ActiveRecord::AssociatedObject
  include LocationInfoMethods

  delegate :city, :state, :latitude, :longitude, to: :event

  def country
    @country ||= if event.country_code.present?
      Country.find_by(country_code: event.country_code)
    else
      find_country_from_string(event.location)
    end
  end

  def country_code
    event.country_code.presence || country&.alpha2
  end

  def to_s
    event.location
  end

  def present?
    event.location.present?
  end

  private

  def location_without_country
    return nil if event.location.blank? || country.blank?

    event.location.gsub(/, #{country.name}$/i, "").strip.presence
  end
end
