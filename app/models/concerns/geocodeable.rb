# frozen_string_literal: true

module Geocodeable
  extend ActiveSupport::Concern

  class_methods do
    attr_reader :geocode_attribute

    def geocodeable(attribute = :location)
      @geocode_attribute = attribute

      geocoded_by attribute do |record, results|
        if (result = results.first)
          record.city = result.city
          record.latitude = result.latitude
          record.longitude = result.longitude
          record.state_code = result.state_code
          record.country_code = result.country_code&.upcase
          record.geocode_metadata = result.data.merge("geocoded_at" => Time.current.iso8601)

          if result.city.present? && record.country_code.present?
            city_record = City.find_or_create_for(
              city: record.city,
              state_code: record.state_code,
              country_code: record.country_code
            )
            record.city = city_record&.name
          else
            record.city = nil
          end
        end
      end

      after_commit :geocode_later, if: :"#{attribute}_previously_changed?"

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
end
