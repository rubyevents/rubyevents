# frozen_string_literal: true

require "test_helper"

class Static::BrandColorsValidatorTest < ActiveSupport::TestCase
  include StaticDataSandbox

  test "does not flag an event without assets or colors" do
    with_event({}) do |event|
      assert_empty brand_color_errors(event)
    end
  end

  test "flags an event with its own asset but no colors" do
    with_event({}, event_assets: ["featured.webp"]) do |event|
      assert_equal [
        "featured_background is not defined but 'app/assets/images/events/testconf/testconf-2025/featured.webp' exists, events with a custom featured.webp must define brand colors",
        "featured_color is not defined but 'app/assets/images/events/testconf/testconf-2025/featured.webp' exists, events with a custom featured.webp must define brand colors"
      ], brand_color_errors(event)

      assert_equal 1, event.error_location(event.errors.first)&.start_line
    end
  end

  test "is run by the lint validations of events and series" do
    with_event({}, event_assets: ["banner.webp"], default_assets: ["banner.webp"]) do |event|
      assert_not event.valid?(:lint)
      assert_includes event.errors.full_messages.join("\n"), "banner_background is not defined"

      series = Static::EventSeries.all.first
      assert_not series.valid?(:lint)
      assert_includes series.errors.full_messages.join("\n"), "banner_background is not defined"
    end
  end

  test "does not flag an event falling back to a series default asset without colors" do
    with_event({}, default_assets: ["banner.webp"]) do |event|
      assert_empty brand_color_errors(event)
    end
  end

  test "does not flag an event with its own assets and colors" do
    colors = {"banner_background" => "#FFFFFF", "featured_background" => "#FFFFFF", "featured_color" => "#000000"}

    with_event(colors, event_assets: ["featured.webp", "banner.webp"]) do |event|
      assert_empty brand_color_errors(event)
    end
  end

  test "does not flag event colors when the event has its own asset next to a series default" do
    with_event({"banner_background" => "#FF0000"}, event_assets: ["banner.webp"], default_assets: ["banner.webp"]) do |event|
      assert_empty brand_color_errors(event)
    end
  end

  test "flags event colors without any matching asset" do
    with_event({"banner_background" => "#FF0000", "featured_color" => "#FF0000"}) do |event|
      assert_equal [
        "banner_background is defined but 'banner.webp' exists neither in app/assets/images/events/testconf/testconf-2025 nor in app/assets/images/events/testconf/default, events falling back to the global default banner.webp must not define brand colors",
        "featured_color is defined but 'featured.webp' exists neither in app/assets/images/events/testconf/testconf-2025 nor in app/assets/images/events/testconf/default, events falling back to the global default featured.webp must not define brand colors"
      ], brand_color_errors(event)

      assert_equal [line_of(event.file_path, "banner_background"), line_of(event.file_path, "featured_color")],
        event.errors.map { |error| event.error_location(error)&.start_line }
    end
  end

  test "flags event colors when the asset comes from the series default" do
    with_event({"featured_background" => "#FF0000", "featured_color" => "#FFFFFF"}, default_assets: ["featured.webp"]) do |event|
      errors = brand_color_errors(event)

      assert_equal 2, errors.size
      assert errors.all? { |message| message.include?("comes from the series default 'app/assets/images/events/testconf/default/featured.webp'") }
      assert errors.all? { |message| message.include?("in data/testconf/series.yml instead") }
    end
  end

  test "does not flag a series without default assets or colors" do
    with_series({}) do |series|
      assert_empty brand_color_errors(series)
    end
  end

  test "does not flag a series with default assets and matching colors" do
    colors = {"banner_background" => "#FFFFFF", "featured_background" => "#FFFFFF", "featured_color" => "#F4554E"}

    with_series(colors, default_assets: ["banner.webp", "featured.webp"]) do |series|
      assert_empty brand_color_errors(series)
    end
  end

  test "flags missing colors when the series has default assets" do
    with_series({}, default_assets: ["featured.webp"]) do |series|
      errors = brand_color_errors(series)

      assert_equal 2, errors.size
      assert_includes errors.first, "featured_background is not defined but 'app/assets/images/events/testconf/default/featured.webp' exists, series with a default featured.webp must define its brand colors"
      assert_includes errors.last, "featured_color is not defined"
    end
  end

  test "flags series colors without a matching default asset" do
    with_series({"banner_background" => "#FFFFFF", "featured_color" => "#000000"}, default_assets: ["featured.webp"]) do |series|
      errors = brand_color_errors(series)

      assert_equal 2, errors.size
      assert_includes errors, "banner_background is defined but 'app/assets/images/events/testconf/default/banner.webp' does not exist, series without a default banner.webp must not define brand colors"
      assert errors.any? { |message| message.start_with?("featured_background is not defined") }

      error = series.errors.find { |e| e.attribute == :banner_background }
      assert_equal line_of(series.file_path, "banner_background"), series.error_location(error)&.start_line
    end
  end

  test "real events and series are consistent with their brand assets" do
    errors = [*Static::EventSeries.all, *Static::Event.all].flat_map do |record|
      brand_color_errors(record).map { |message| "#{record.file_path}: #{message}" }
    end

    assert_empty errors
  end

  private

  def brand_color_errors(record)
    record.errors.clear
    Static::BrandColorsValidator.new.validate(record)

    record.errors.full_messages
  end

  def line_of(file_path, key)
    File.readlines(file_path).index { |line| line.start_with?("#{key}:") } + 1
  end

  def with_event(attributes, event_assets: [], default_assets: [])
    with_static_data_dir do |root|
      write_yaml(File.join(root, "data/testconf/series.yml"), {"name" => "TestConf"})
      write_yaml(File.join(root, "data/testconf/testconf-2025/event.yml"), {"name" => "TestConf 2025", "kind" => "conference"}.merge(attributes))
      write_assets(root, "testconf-2025", event_assets)
      write_assets(root, "default", default_assets)

      yield Static::Event.all.first
    end
  end

  def with_series(attributes, default_assets: [])
    with_static_data_dir do |root|
      write_yaml(File.join(root, "data/testconf/series.yml"), {"name" => "TestConf"}.merge(attributes))
      write_assets(root, "default", default_assets)

      yield Static::EventSeries.all.first
    end
  end

  def write_yaml(path, attributes)
    FileUtils.mkdir_p(File.dirname(path))
    Yerba::Document.from(attributes).save_to!(path)
  end

  def write_assets(root, folder, assets)
    directory = File.join(root, "app/assets/images/events/testconf", folder)
    FileUtils.mkdir_p(directory)
    assets.each { |asset| FileUtils.touch(File.join(directory, asset)) }
  end
end
