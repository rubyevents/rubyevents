class Talk::LocationInfo
  attr_reader :location

  def initialize(location)
    @location = location
  end

  def geocoded?
    false
  end

  def present?
    location.present?
  end

  def to_s
    location
  end

  def city = nil
  def state = nil
  def country = nil
  def country_code = nil
  def display_city = nil
  def state_path = nil
  def city_path = nil
end
