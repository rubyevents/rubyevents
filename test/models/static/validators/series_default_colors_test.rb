# frozen_string_literal: true

require "test_helper"

class Static::Validators::SeriesDefaultColorsTest < ActiveSupport::TestCase
  test "applicable? returns true for an event.yml file" do
    file = Dir.glob(Rails.root.join("data/**/event.yml")).first.to_s
    assert Static::Validators::SeriesDefaultColors.new(file_path: file).applicable?
  end

  test "applicable? returns false for a non-event file" do
    file = Dir.glob(Rails.root.join("data/**/videos.yml")).first.to_s
    assert_not Static::Validators::SeriesDefaultColors.new(file_path: file).applicable?
  end

  test "applicable? returns false for a non-existent file" do
    assert_not Static::Validators::SeriesDefaultColors.new(file_path: "/nonexistent/event.yml").applicable?
  end

  test "does not flag events with matching colors" do
    events = {
      "testconf-2024" => {"featured_background" => "#FFFFFF", "featured_color" => "#F4554E", "banner_background" => "#FFFFFF"},
      "testconf-2025" => {"featured_background" => "#FFFFFF", "featured_color" => "#F4554E", "banner_background" => "#FFFFFF"}
    }

    with_temp_series(events, default_assets: ["featured.webp", "banner.webp"]) do |data_root, assets_root|
      assert_empty errors_for(data_root, assets_root)
    end
  end

  test "flags an event whose color differs from other events falling back to the default asset" do
    events = {
      "testconf-2024" => {"featured_color" => "#F4554E"},
      "testconf-2025" => {"featured_color" => "#F4554E"},
      "testconf-2026" => {"featured_color" => "#000000"}
    }

    with_temp_series(events, default_assets: ["featured.webp"]) do |data_root, assets_root|
      errors = errors_for(data_root, assets_root)

      assert_equal 1, errors.size
      assert_includes errors.first.message, %(featured_color "#000000" does not match "#F4554E")
      assert_includes errors.first.file_path, "testconf-2026"
    end
  end

  test "does not flag events with their own asset" do
    events = {
      "testconf-2024" => {"featured_background" => "#FFFFFF"},
      "testconf-2025" => {"featured_background" => "#123456"}
    }

    with_temp_series(events, default_assets: ["featured.webp"], event_assets: {"testconf-2025" => ["featured.webp"]}) do |data_root, assets_root|
      assert_empty errors_for(data_root, assets_root)
    end
  end

  test "does not flag fields whose asset is missing from the default directory" do
    events = {
      "testconf-2024" => {"banner_background" => "#FFFFFF"},
      "testconf-2025" => {"banner_background" => "#123456"}
    }

    with_temp_series(events, default_assets: ["featured.webp"]) do |data_root, assets_root|
      assert_empty errors_for(data_root, assets_root)
    end
  end

  test "does not flag a series without a default asset directory" do
    events = {
      "testconf-2024" => {"featured_color" => "#F4554E"},
      "testconf-2025" => {"featured_color" => "#000000"}
    }

    with_temp_series(events, default_assets: nil) do |data_root, assets_root|
      assert_empty errors_for(data_root, assets_root)
    end
  end

  test "compares banner_background and featured_background independently" do
    events = {
      "testconf-2024" => {"banner_background" => "#FFFFFF", "featured_background" => "#FFFFFF"},
      "testconf-2025" => {"banner_background" => "#FFFFFF", "featured_background" => "#000000"},
      "testconf-2026" => {"banner_background" => "#FFFFFF", "featured_background" => "#FFFFFF"}
    }

    with_temp_series(events, default_assets: ["featured.webp", "banner.webp"]) do |data_root, assets_root|
      errors = errors_for(data_root, assets_root)

      assert_equal 1, errors.size
      assert_includes errors.first.message, "featured_background"
    end
  end

  test "errors are Static::Validators::Error objects" do
    events = {
      "testconf-2024" => {"featured_color" => "#F4554E"},
      "testconf-2025" => {"featured_color" => "#F4554E"},
      "testconf-2026" => {"featured_color" => "#000000"}
    }

    with_temp_series(events, default_assets: ["featured.webp"]) do |data_root, assets_root|
      assert errors_for(data_root, assets_root).all? { |error| error.is_a?(Static::Validators::Error) }
    end
  end

  test "returns empty errors for all real event.yml files" do
    Static::Validators::SeriesDefaultColors.reset!

    errors = Dir.glob(Rails.root.join("data/**/event.yml")).flat_map do |file|
      Static::Validators::SeriesDefaultColors.new(file_path: file).errors
    end

    assert_empty errors
  ensure
    Static::Validators::SeriesDefaultColors.reset!
  end

  private

  def errors_for(data_root, assets_root)
    Static::Validators::SeriesDefaultColors.mismatch_errors(data_root: data_root, assets_root: assets_root)
  end

  def with_temp_series(events, default_assets:, event_assets: {})
    dir = Dir.mktmpdir
    data_root = File.join(dir, "data")
    assets_root = File.join(dir, "assets")

    events.each do |event_slug, attributes|
      event_path = File.join(data_root, "testconf", event_slug, "event.yml")
      FileUtils.mkdir_p(File.dirname(event_path))
      File.write(event_path, attributes.to_yaml)
    end

    Array(default_assets).each do |asset|
      default_dir = File.join(assets_root, "testconf", "default")
      FileUtils.mkdir_p(default_dir)
      FileUtils.touch(File.join(default_dir, asset))
    end

    event_assets.each do |event_slug, assets|
      event_dir = File.join(assets_root, "testconf", event_slug)
      FileUtils.mkdir_p(event_dir)
      assets.each { |asset| FileUtils.touch(File.join(event_dir, asset)) }
    end

    yield data_root, assets_root
  ensure
    FileUtils.rm_rf(dir)
  end
end
