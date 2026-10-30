# frozen_string_literal: true

require "test_helper"

class Static::Validators::SeriesDefaultColorsTest < ActiveSupport::TestCase
  test "applicable? returns true for a series.yml file" do
    file = Dir.glob(Rails.root.join("data/*/series.yml")).first.to_s
    assert Static::Validators::SeriesDefaultColors.new(file_path: file).applicable?
  end

  test "applicable? returns false for an event.yml file" do
    file = Dir.glob(Rails.root.join("data/**/event.yml")).first.to_s
    assert_not Static::Validators::SeriesDefaultColors.new(file_path: file).applicable?
  end

  test "applicable? returns false for a non-existent file" do
    assert_not Static::Validators::SeriesDefaultColors.new(file_path: "/nonexistent/series.yml").applicable?
  end

  test "does not flag a series without default assets or colors" do
    with_temp_series({"name" => "TestConf"}) do |file_path|
      assert_empty Static::Validators::SeriesDefaultColors.new(file_path: file_path).errors
    end
  end

  test "does not flag a series with default assets and matching colors" do
    series = {"name" => "TestConf", "banner_background" => "#FFFFFF", "featured_background" => "#FFFFFF", "featured_color" => "#F4554E"}

    with_temp_series(series, default_assets: ["banner.webp", "featured.webp"]) do |file_path|
      assert_empty Static::Validators::SeriesDefaultColors.new(file_path: file_path).errors
    end
  end

  test "flags missing colors when the series has default assets" do
    with_temp_series({"name" => "TestConf"}, default_assets: ["featured.webp"]) do |file_path|
      errors = Static::Validators::SeriesDefaultColors.new(file_path: file_path).errors

      assert_equal 2, errors.size
      assert errors.any? { |e| e.message.include?("featured_background is not defined but 'app/assets/images/events/testconf/default/featured.webp' exists") }
      assert errors.any? { |e| e.message.include?("featured_color is not defined") }
    end
  end

  test "flags colors without a matching default asset" do
    series = {"name" => "TestConf", "banner_background" => "#FFFFFF", "featured_color" => "#000000"}

    with_temp_series(series, default_assets: ["featured.webp"]) do |file_path|
      errors = Static::Validators::SeriesDefaultColors.new(file_path: file_path).errors

      assert_equal 2, errors.size
      assert errors.any? { |e| e.message.include?("banner_background is defined but 'app/assets/images/events/testconf/default/banner.webp' does not exist") }
      assert errors.any? { |e| e.message.include?("featured_background is not defined") }
    end
  end

  test "returns empty errors for all real series.yml files" do
    errors = Dir.glob(Rails.root.join("data/*/series.yml")).flat_map do |file|
      Static::Validators::SeriesDefaultColors.new(file_path: file).errors
    end

    assert_empty errors
  end

  private

  def with_temp_series(attributes, default_assets: [])
    dir = Dir.mktmpdir
    file_path = File.join(dir, "data", "testconf", "series.yml")
    FileUtils.mkdir_p(File.dirname(file_path))
    File.write(file_path, attributes.to_yaml)

    default_dir = File.join(dir, "app", "assets", "images", "events", "testconf", "default")

    default_assets.each do |asset|
      FileUtils.mkdir_p(default_dir)
      FileUtils.touch(File.join(default_dir, asset))
    end

    yield file_path
  ensure
    FileUtils.rm_rf(dir)
  end
end
