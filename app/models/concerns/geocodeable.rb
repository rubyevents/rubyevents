# frozen_string_literal: true

module Geocodeable
  extend ActiveSupport::Concern

  included do
    geocoded_by :location do |record, results|
      if (result = results.first)
        record.latitude ||= result.latitude
        record.longitude ||= result.longitude
        record.city = result.city
        record.state = result.state_code
        record.country_code = result.country_code&.upcase
        record.geocode_metadata = result.data.merge("geocoded_at" => Time.current.iso8601)
      end
    end

    after_commit :geocode_later, if: :location_previously_changed?

    scope :with_coordinates, -> { where.not(latitude: nil).where.not(longitude: nil) }
    scope :without_coordinates, -> { where(latitude: nil).or(where(longitude: nil)) }
  end

  def geocodeable?
    location.present?
  end

  def clear_geocode
    self.latitude = nil
    self.longitude = nil
    self.city = nil
    self.state = nil
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
