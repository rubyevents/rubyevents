# frozen_string_literal: true

module Geocodeable
  extend ActiveSupport::Concern

  class_methods do
    attr_reader :geocode_attribute

    def city_from_result(result)
      result.data["formatted_address"]&.split(",")&.first&.strip
    end

    def geocodeable(attribute = :location)
      @geocode_attribute = attribute

      geocoded_by attribute do |record, results|
        if (result = results.first)
          record.latitude ||= result.latitude
          record.longitude ||= result.longitude
          record.city = result.city || city_from_result(result)
          record.state_code = result.state_code
          record.country_code = result.country_code&.upcase
          record.geocode_metadata = result.data.merge("geocoded_at" => Time.current.iso8601)
        end
      end

      after_commit :geocode_later, if: :"#{attribute}_previously_changed?"
      after_commit :create_or_update_city_record, if: :city_changed_for_city_record?

      scope :with_coordinates, -> { where.not(latitude: nil).where.not(longitude: nil) }
      scope :without_coordinates, -> { where(latitude: nil).or(where(longitude: nil)) }
    end
  end

  def geocodeable?
    send(self.class.geocode_attribute).present?
  end

  def clear_geocode
    self.latitude = nil
    self.longitude = nil
    self.city = nil
    self.state_code = nil
    self.country_code = nil
    self.geocode_metadata = {}
  end

  def regeocode
    clear_geocode
    geocode
  end

  def geocode!
    geocode
    save!
  end

  def clear_geocode!
    clear_geocode
    save!
  end

  def regeocode!
    regeocode
    save!
  end

  private

  def geocode_later
    GeocodeRecordJob.perform_later(self)
  end

  def city_changed_for_city_record?
    city.present? && country_code.present? &&
      (saved_change_to_city? || saved_change_to_country_code? || saved_change_to_state_code?)
  end

  def create_or_update_city_record
    City.find_or_create_for(
      city: city,
      country_code: country_code,
      state_code: state_code,
      latitude: latitude,
      longitude: longitude
    )
  end
end
