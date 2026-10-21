# frozen_string_literal: true

require "test_helper"

class Static::LocationCountryValidatorTest < ActiveSupport::TestCase
  include StaticDataSandbox

  test "does not flag locations ending in the country written out" do
    ["London, United Kingdom", "Portland, OR, United States", "Edinburgh, Scotland, United Kingdom", "Singapore", "Brno, Czech Republic", "online"].each do |location|
      with_event(location) do |event|
        assert_empty location_errors(event), location
      end
    end
  end

  test "flags a country code and suggests the country written out" do
    with_event("London, UK") do |event|
      errors = location_errors(event)

      assert_equal 1, errors.size
      assert_includes errors.first, %(location "London, UK" should end in the country written out: "London, United Kingdom")
      assert_equal 4, event.error_location(event.errors.where(:location).first).start_line
    end
  end

  test "suggests adding the country after a state code" do
    with_event("Washington, DC") do |event|
      assert_equal "Washington, DC, United States", validator.suggested_location(event)
    end
  end

  test "suggests no country for a code that is a country and a state" do
    with_event("Berkeley, CA") do |event|
      assert_nil validator.suggested_location(event)
      assert_includes location_errors(event).first, %(location "Berkeley, CA" should end in the country written out, like)
    end
  end

  test "reads a code that is a country and a state as a state of the series' default country" do
    with_series("Berkeley, CA", default_country_code: "US") do |series|
      assert_equal "Berkeley, CA, United States", validator.suggested_location(series)
    end
  end

  test "flags a location without a country" do
    with_event("Bryant Pond, Maine") do |event|
      assert_equal 1, location_errors(event).size
      assert_nil validator.suggested_location(event)
    end
  end

  test "flags a series location" do
    with_series("London, UK") do |series|
      assert_not series.valid?(:lint)
      assert_includes series.errors.full_messages_for(:location).first, %("London, United Kingdom")
    end
  end

  test "fix writes the country out" do
    with_event("Sydney, NSW, AU") do |event, path|
      assert_equal 1, Yerba::Record.fix_all([event], only: Static::LocationCountryValidator).sum(&:last)
      assert_includes File.read(path), %(location: "Sydney, NSW, Australia")
    end
  end

  test "fix leaves a location alone when there is nothing to suggest" do
    with_event("Berkeley, CA") do |event, path|
      assert_empty Yerba::Record.fix_all([event], only: Static::LocationCountryValidator)
      assert_includes File.read(path), %(location: "Berkeley, CA")
    end
  end

  private

  def validator
    Static::Event.validators.find { |validator| validator.is_a?(Static::LocationCountryValidator) }
  end

  def location_errors(event)
    event.valid?(:lint)
    event.errors.full_messages_for(:location)
  end

  def with_event(location)
    with_static_data_dir do |root|
      path = File.join(root, "data", "testconf", "testconf-2024", "event.yml")
      FileUtils.mkdir_p(File.dirname(path))
      File.write(File.join(root, "data", "testconf", "series.yml"), %(---\nid: "testconf"\nname: "TestConf"\nkind: "conference"\n))
      File.write(path, <<~YAML)
        ---
        id: "testconf-2024"
        title: "TestConf 2024"
        location: "#{location}"
      YAML

      yield Static::Event.in_file(path).first, path
    end
  end

  def with_series(location, default_country_code: nil)
    with_static_data_dir do |root|
      path = File.join(root, "data", "testconf", "series.yml")
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, <<~YAML)
        ---
        id: "testconf"
        name: "TestConf"
        location: "#{location}"
        #{%(default_country_code: "#{default_country_code}") if default_country_code}
      YAML

      yield Static::EventSeries.in_file(path).first
    end
  end
end
