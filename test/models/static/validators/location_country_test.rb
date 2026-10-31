# frozen_string_literal: true

require "test_helper"

class Static::Validators::LocationCountryTest < ActiveSupport::TestCase
  test "applicable? returns true for an event.yml file" do
    file = Dir.glob(Rails.root.join("data/**/event.yml")).first

    assert Static::Validators::LocationCountry.new(file_path: file).applicable?
  end

  test "applicable? returns true for a series.yml file" do
    file = Dir.glob(Rails.root.join("data/**/series.yml")).first

    assert Static::Validators::LocationCountry.new(file_path: file).applicable?
  end

  test "applicable? returns false for a videos.yml file" do
    file = Dir.glob(Rails.root.join("data/**/videos.yml")).first

    assert_not Static::Validators::LocationCountry.new(file_path: file).applicable?
  end

  test "does not flag locations ending in the country written out" do
    ["London, United Kingdom", "Portland, OR, United States", "Edinburgh, Scotland, United Kingdom", "Singapore", "Brno, Czech Republic", "online"].each do |location|
      with_temp_event(location) do |path|
        assert_empty validator(path).errors, location
      end
    end
  end

  test "flags a country code and suggests the country written out" do
    with_temp_event("London, UK") do |path|
      errors = validator(path).errors

      assert_equal 1, errors.size
      assert_includes errors.first.message, %("London, UK" should end in the country written out: "London, United Kingdom")
    end
  end

  test "suggests adding the country after a state code" do
    with_temp_event("Washington, DC") do |path|
      assert_equal "Washington, DC, United States", validator(path).suggested_location
    end
  end

  test "suggests no country for a code that is a country and a state" do
    with_temp_event("Berkeley, CA") do |path|
      assert_nil validator(path).suggested_location
      assert_includes validator(path).errors.first.message, %("Berkeley, CA" should end in the country written out, like)
    end
  end

  test "reads a code that is a country and a state as a state of the series' default country" do
    with_temp_series("Berkeley, CA", default_country_code: "US") do |path|
      assert_equal "Berkeley, CA, United States", validator(path).suggested_location
    end
  end

  test "flags a location without a country" do
    with_temp_event("Bryant Pond, Maine") do |path|
      assert_equal 1, validator(path).errors.size
      assert_nil validator(path).suggested_location
    end
  end

  test "fix writes the country out" do
    with_temp_event("Sydney, NSW, AU") do |path|
      assert_equal({changed: 1, file_path: path}, validator(path).fix)
      assert_includes File.read(path), %(location: "Sydney, NSW, Australia")
    end
  end

  test "fix leaves a location alone when there is nothing to suggest" do
    with_temp_event("Berkeley, CA") do |path|
      assert_nil validator(path).fix
      assert_includes File.read(path), %(location: "Berkeley, CA")
    end
  end

  private

  def validator(path)
    Static::Validators::LocationCountry.new(file_path: path)
  end

  def with_temp_event(location)
    with_temp_file("testconf/testconf-2024/event.yml", <<~YAML) { |path| yield path }
      ---
      id: "testconf-2024"
      title: "TestConf 2024"
      location: "#{location}"
    YAML
  end

  def with_temp_series(location, default_country_code:)
    with_temp_file("testconf/series.yml", <<~YAML) { |path| yield path }
      ---
      id: "testconf"
      name: "TestConf"
      location: "#{location}"
      default_country_code: "#{default_country_code}"
    YAML
  end

  def with_temp_file(relative_path, content)
    dir = Dir.mktmpdir
    path = File.join(dir, "data", relative_path)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)

    yield path
  ensure
    FileUtils.rm_rf(dir)
  end
end
