# frozen_string_literal: true

require "test_helper"

class Static::CityNameValidatorTest < ActiveSupport::TestCase
  include StaticDataSandbox

  test "accepts the canonical city name" do
    assert_empty location_errors("Las Vegas, USA")
  end

  test "ignores a missing location" do
    assert_empty location_errors(nil)
  end

  test "ignores cities that are not featured" do
    assert_empty location_errors("Unknown City, Country")
  end

  test "flags a city alias" do
    assert_equal [%(location uses city alias "Vegas" instead of canonical name "Las Vegas")], location_errors("Vegas, USA")
  end

  test "matches aliases case-insensitively" do
    assert_equal [%(location uses city alias "vegas" instead of canonical name "Las Vegas")], location_errors("vegas, USA")
  end

  test "handles a location with just the city name" do
    assert_equal [%(location uses city alias "Vegas" instead of canonical name "Las Vegas")], location_errors("Vegas")
  end

  test "points at the location line" do
    with_event("Vegas, USA") do |event|
      event.valid?(:lint)

      assert_equal 4, event.error_location(event.errors.where(:location).first).start_line
    end
  end

  private

  def location_errors(location)
    with_event(location) do |event|
      event.valid?(:lint)
      event.errors.full_messages_for(:location)
    end
  end

  def with_event(location)
    with_static_data_dir do |root|
      path = File.join(root, "data", "testconf", "testconf-2025", "event.yml")
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, <<~YAML)
        ---
        id: "testconf-2025"
        title: "TestConf"
        #{%(location: "#{location}") if location}
      YAML

      yield Static::Event.in_file(path).first
    end
  end
end
