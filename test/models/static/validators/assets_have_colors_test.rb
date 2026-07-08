# frozen_string_literal: true

require "test_helper"

class Static::Validators::AssetsHaveColorsTest < ActiveSupport::TestCase
  VALID_EVENT_FILE = Dir.glob(Rails.root.join("data/**/event.yml")).first.to_s

  test "applicable? returns true for an event.yml file" do
    validator = Static::Validators::AssetsHaveColors.new(file_path: VALID_EVENT_FILE)
    assert validator.applicable?
  end

  test "applicable? returns false for a non-event file" do
    file = Dir.glob(Rails.root.join("data/**/videos.yml")).first.to_s
    validator = Static::Validators::AssetsHaveColors.new(file_path: file)
    assert_not validator.applicable?
  end

  test "applicable? returns false for a non-existent file" do
    validator = Static::Validators::AssetsHaveColors.new(file_path: "/nonexistent/event.yml")
    assert_not validator.applicable?
  end

  test "returns empty errors when the event has no assets" do
    event = {"name" => "TestConf", "kind" => "conference"}.to_yaml
    with_temp_event(event) do |file_path|
      validator = Static::Validators::AssetsHaveColors.new(file_path: file_path)
      assert_empty validator.errors
    end
  end

  test "returns empty errors for all real event.yml files" do
    errors = Dir.glob(Rails.root.join("data/**/event.yml")).flat_map do |f|
      Static::Validators::AssetsHaveColors.new(file_path: f).errors
    end
    assert_empty errors
  end

  test "flags an event with its own asset but no colors" do
    event = {"name" => "TestConf", "kind" => "conference"}.to_yaml
    with_temp_event(event, event_assets: ["featured.webp"]) do |file_path|
      errors = Static::Validators::AssetsHaveColors.new(file_path: file_path).errors

      assert errors.any? { |e| e.message.include?("featured_background is not defined") }
      assert errors.any? { |e| e.message.include?("featured_color is not defined") }
      assert_not errors.any? { |e| e.message.include?("banner_background") }
    end
  end

  test "flags an event falling back to a series default asset without colors" do
    event = {"name" => "TestConf", "kind" => "conference"}.to_yaml
    with_temp_event(event, default_assets: ["banner.webp"]) do |file_path|
      errors = Static::Validators::AssetsHaveColors.new(file_path: file_path).errors

      assert_equal 1, errors.size
      assert_includes errors.first.message, "banner_background is not defined"
      assert_includes errors.first.message, "app/assets/images/events/testconf/default/banner.webp"
    end
  end

  test "does not flag when colors are defined" do
    event = {
      "name" => "TestConf",
      "banner_background" => "#FFFFFF",
      "featured_background" => "#FFFFFF",
      "featured_color" => "#000000"
    }.to_yaml

    with_temp_event(event, event_assets: ["featured.webp", "banner.webp"]) do |file_path|
      assert_empty Static::Validators::AssetsHaveColors.new(file_path: file_path).errors
    end
  end

  private

  def with_temp_event(event_yaml, series_slug: "testconf", event_slug: "testconf-2025", event_assets: [], default_assets: [])
    dir = Dir.mktmpdir
    file_path = File.join(dir, "data", series_slug, event_slug, "event.yml")
    FileUtils.mkdir_p(File.dirname(file_path))
    File.write(file_path, event_yaml)

    {event_slug => event_assets, "default" => default_assets}.each do |slug, assets|
      asset_dir = File.join(dir, "app", "assets", "images", "events", series_slug, slug)

      assets.each do |asset|
        FileUtils.mkdir_p(asset_dir)
        FileUtils.touch(File.join(asset_dir, asset))
      end
    end

    yield file_path
  ensure
    FileUtils.rm_rf(dir)
  end
end
