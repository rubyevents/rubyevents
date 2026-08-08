# frozen_string_literal: true

require "test_helper"

class Static::Validators::OrphanedEventAssetsTest < ActiveSupport::TestCase
  test "applicable? returns true for an event asset" do
    file = Dir.glob(Rails.root.join("app/assets/images/events/**/*.webp")).first.to_s
    assert Static::Validators::OrphanedEventAssets.new(file_path: file).applicable?
  end

  test "applicable? returns false for a non-webp file" do
    assert_not Static::Validators::OrphanedEventAssets.new(file_path: __FILE__).applicable?
  end

  test "applicable? returns false for a webp outside the events directory" do
    file = Dir.glob(Rails.root.join("app/assets/images/thumbnails/**/*.webp")).first.to_s
    assert_not Static::Validators::OrphanedEventAssets.new(file_path: file).applicable?
  end

  test "does not flag assets of an existing event" do
    series_slug, event_slug = existing_event_with_assets
    file = Dir.glob(Rails.root.join("app/assets/images/events", series_slug, event_slug, "*.webp")).first.to_s

    assert_empty Static::Validators::OrphanedEventAssets.new(file_path: file).errors
  end

  test "does not flag global default assets" do
    file = Rails.root.join("app/assets/images/events/default/featured.webp").to_s

    assert_empty Static::Validators::OrphanedEventAssets.new(file_path: file).errors
  end

  test "does not flag series default assets" do
    file = Rails.root.join("app/assets/images/events/rubyconf/default/featured.webp").to_s

    assert_empty Static::Validators::OrphanedEventAssets.new(file_path: file).errors
  end

  test "flags assets of an unknown event" do
    with_temp_asset("rubyconf", "rubyconf-1999") do |file|
      errors = Static::Validators::OrphanedEventAssets.new(file_path: file).errors

      assert_equal 1, errors.size
      assert_includes errors.first.message, "data/rubyconf/rubyconf-1999"
    end
  end

  test "flags assets of an unknown series" do
    with_temp_asset("nosuchconf", "default") do |file|
      errors = Static::Validators::OrphanedEventAssets.new(file_path: file).errors

      assert_equal 1, errors.size
      assert_includes errors.first.message, "data/nosuchconf"
    end
  end

  test "returns no errors for all real event assets" do
    errors = Dir.glob(Rails.root.join("app/assets/images/events/**/*.webp")).flat_map do |file|
      Static::Validators::OrphanedEventAssets.new(file_path: file).errors
    end

    assert_empty errors
  end

  private

  def existing_event_with_assets
    Dir.glob(Rails.root.join("app/assets/images/events/*/*/*.webp")).each do |file|
      series_slug, event_slug = file.split("/")[-3..-2]
      next if event_slug == "default"
      return [series_slug, event_slug] if File.exist?(Rails.root.join("data", series_slug, event_slug, "event.yml"))
    end
  end

  def with_temp_asset(series_slug, event_slug)
    dir = Rails.root.join("app/assets/images/events", series_slug, event_slug)
    file = dir.join("featured.webp")

    raise "refusing to overwrite existing asset" if File.exist?(file)

    FileUtils.mkdir_p(dir)
    FileUtils.touch(file)

    yield file.to_s
  ensure
    FileUtils.rm_f(file)
    FileUtils.rmdir(dir) if Dir.exist?(dir) && Dir.empty?(dir)
  end
end
