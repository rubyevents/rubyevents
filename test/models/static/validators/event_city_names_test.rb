# frozen_string_literal: true

require "test_helper"

class Static::Validators::EventCityNamesTest < ActiveSupport::TestCase
  test "applicable? returns true for an event.yml file" do
    validator = Static::Validators::EventCityNames.new(file_path: "/data/rubyconf/rubyconf-2026/event.yml")
    assert validator.applicable?
  end

  test "applicable? returns false for a non-event.yml file" do
    file = Dir.glob(Rails.root.join("data/**/videos.yml")).first
    validator = Static::Validators::EventCityNames.new(file_path: file)
    assert_not validator.applicable?
  end

  test "applicable? returns false for a non-existent file" do
    validator = Static::Validators::EventCityNames.new(file_path: "/nonexistent/event.yml")
    assert_not validator.applicable?
  end

  test "returns empty errors when location uses canonical city name" do
    yaml = {"name" => "RubyConf", "location" => "Las Vegas, USA"}.to_yaml
    with_temp_event_yaml(yaml) do |path|
      validator = Static::Validators::EventCityNames.new(file_path: path)
      assert_empty validator.errors
    end
  end

  test "returns empty errors when location is blank" do
    yaml = {"name" => "RubyConf"}.to_yaml
    with_temp_event_yaml(yaml) do |path|
      validator = Static::Validators::EventCityNames.new(file_path: path)
      assert_empty validator.errors
    end
  end

  test "returns empty errors when city is not in featured cities" do
    yaml = {"name" => "RubyConf", "location" => "Unknown City, Country"}.to_yaml
    with_temp_event_yaml(yaml) do |path|
      validator = Static::Validators::EventCityNames.new(file_path: path)
      assert_empty validator.errors
    end
  end

  test "returns error when location uses city alias instead of canonical name" do
    yaml = {"name" => "RubyConf", "location" => "Vegas, USA"}.to_yaml
    with_temp_event_yaml(yaml) do |path|
      validator = Static::Validators::EventCityNames.new(file_path: path)
      errors = validator.errors
      assert_equal 1, errors.count
      assert errors.first.to_h["message"].include?("Vegas")
      assert errors.first.to_h["message"].include?("Las Vegas")
      assert errors.first.to_h["message"].include?("canonical")
    end
  end

  test "errors are Static::Validators::Error objects" do
    yaml = {"name" => "RubyConf", "location" => "Vegas, USA"}.to_yaml
    with_temp_event_yaml(yaml) do |path|
      validator = Static::Validators::EventCityNames.new(file_path: path)
      assert validator.errors.all? { |e| e.is_a?(Static::Validators::Error) }
    end
  end

  test "case-insensitive matching for alias detection" do
    yaml = {"name" => "RubyConf", "location" => "vegas, USA"}.to_yaml
    with_temp_event_yaml(yaml) do |path|
      validator = Static::Validators::EventCityNames.new(file_path: path)
      errors = validator.errors
      assert_equal 1, errors.count
      assert errors.first.to_h["message"].include?("vegas")
      assert errors.first.to_h["message"].include?("Las Vegas")
    end
  end

  test "handles location with just city name (no comma)" do
    yaml = {"name" => "RubyConf", "location" => "Vegas"}.to_yaml
    with_temp_event_yaml(yaml) do |path|
      validator = Static::Validators::EventCityNames.new(file_path: path)
      errors = validator.errors
      assert_equal 1, errors.count
      assert errors.first.to_h["message"].include?("Vegas")
      assert errors.first.to_h["message"].include?("Las Vegas")
    end
  end

  private

  def with_temp_event_yaml(yaml_content)
    dir = Dir.mktmpdir
    path = File.join(dir, "data", "testconf", "2025", "event.yml")
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, yaml_content)
    yield path
  ensure
    FileUtils.rm_rf(dir)
  end
end
