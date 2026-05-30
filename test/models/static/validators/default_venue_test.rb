# frozen_string_literal: true

require "test_helper"

class Static::Validators::DefaultVenueTest < ActiveSupport::TestCase
  test "applicable? returns true for a venue.yml file" do
    file = Dir.glob(Rails.root.join("data/**/venue.yml")).first
    validator = Static::Validators::DefaultVenue.new(file_path: file)
    assert validator.applicable?
  end

  test "applicable? returns false for a non-venue.yml file" do
    file = Dir.glob(Rails.root.join("data/**/event.yml")).first
    validator = Static::Validators::DefaultVenue.new(file_path: file)
    assert_not validator.applicable?
  end

  test "applicable? returns false for a non-existent file" do
    validator = Static::Validators::DefaultVenue.new(file_path: "/nonexistent/venue.yml")
    assert_not validator.applicable?
  end

  test "returns empty errors for a filled-in venue" do
    yaml = {
      "name" => "The Leonardo",
      "description" => "A science and art museum",
      "address" => {"display" => "209 E 500 S, Salt Lake City, UT 84111, USA"}
    }.to_yaml
    with_temp_venue_yaml(yaml) do |path|
      validator = Static::Validators::DefaultVenue.new(file_path: path)
      assert_empty validator.errors
    end
  end

  test "returns error when name is the default TODO placeholder" do
    yaml = {"name" => "TODO"}.to_yaml
    with_temp_venue_yaml(yaml) do |path|
      validator = Static::Validators::DefaultVenue.new(file_path: path)
      assert validator.errors.any? { |e| e.to_h["message"].include?("name") }
    end
  end

  test "returns error when name is the default 'TODO Venue name' placeholder" do
    yaml = {"name" => "TODO Venue name"}.to_yaml
    with_temp_venue_yaml(yaml) do |path|
      validator = Static::Validators::DefaultVenue.new(file_path: path)
      assert validator.errors.any? { |e| e.to_h["message"].include?("name") }
    end
  end

  test "returns error when description is the default placeholder" do
    yaml = {
      "name" => "Real Venue",
      "description" => "TODO - Description of the venue - Optional"
    }.to_yaml
    with_temp_venue_yaml(yaml) do |path|
      validator = Static::Validators::DefaultVenue.new(file_path: path)
      assert validator.errors.any? { |e| e.to_h["message"].include?("description") }
    end
  end

  test "returns error when instructions is the default placeholder" do
    yaml = {
      "name" => "Real Venue",
      "instructions" => "Instructions for getting to the venue - Optional"
    }.to_yaml
    with_temp_venue_yaml(yaml) do |path|
      validator = Static::Validators::DefaultVenue.new(file_path: path)
      assert validator.errors.any? { |e| e.to_h["message"].include?("instructions") }
    end
  end

  test "returns error when url is the default placeholder" do
    yaml = {
      "name" => "Real Venue",
      "url" => "Venue website url - Optional"
    }.to_yaml
    with_temp_venue_yaml(yaml) do |path|
      validator = Static::Validators::DefaultVenue.new(file_path: path)
      assert validator.errors.any? { |e| e.to_h["message"].include?("url") }
    end
  end

  test "returns error when address.display is the default placeholder" do
    yaml = {
      "name" => "Real Venue",
      "address" => {"display" => "123 TODO St, City, State, ZIP, Country"}
    }.to_yaml
    with_temp_venue_yaml(yaml) do |path|
      validator = Static::Validators::DefaultVenue.new(file_path: path)
      assert validator.errors.any? { |e| e.to_h["message"].include?("address.display") }
    end
  end

  test "errors are Static::Validators::Error objects" do
    yaml = {"name" => "TODO"}.to_yaml
    with_temp_venue_yaml(yaml) do |path|
      validator = Static::Validators::DefaultVenue.new(file_path: path)
      assert validator.errors.all? { |e| e.is_a?(Static::Validators::Error) }
    end
  end

  private

  def with_temp_venue_yaml(yaml_content)
    dir = Dir.mktmpdir
    path = File.join(dir, "data", "testconf", "2025", "venue.yml")
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, yaml_content)
    yield path
  ensure
    FileUtils.rm_rf(dir)
  end
end
