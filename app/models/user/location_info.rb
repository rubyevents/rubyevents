class User::LocationInfo < ActiveRecord::AssociatedObject
  include LocationInfoMethods

  delegate :city, :state, :latitude, :longitude, to: :user

  def country
    @country ||= if user.country_code.present?
      Country.find_by(country_code: user.country_code)
    else
      find_country_from_string(user.location)
    end
  end

  def country_code
    user.country_code.presence || country&.alpha2
  end

  def to_s
    user.location
  end

  def present?
    user.location.present?
  end

  private

  def location_without_country
    return nil if user.location.blank? || country.blank?

    user.location.gsub(/, #{country.name}$/i, "").strip.presence
  end
end
