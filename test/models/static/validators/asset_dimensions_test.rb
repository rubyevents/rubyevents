# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"

class Static::Validators::AssetDimensionsTest < ActiveSupport::TestCase
  VALID_ASSET_FILE = Rails.root.join("app/assets/images/events/default/avatar.webp").to_s

  test "applicable? returns true for a webp asset" do
    validator = Static::Validators::AssetDimensions.new(file_path: VALID_ASSET_FILE)
    assert validator.applicable?
  end

  test "applicable? returns false for a non-webp file" do
    validator = Static::Validators::AssetDimensions.new(file_path: Rails.root.join("data/blue-ridge-ruby/series.yml"))
    assert_not validator.applicable?
  end

  test "applicable? returns false for a non-existent file" do
    validator = Static::Validators::AssetDimensions.new(file_path: "/nonexistent/avatar.webp")
    assert_not validator.applicable?
  end

  test "returns expected dimensions for core assets" do
    assert_equal({width: 256, height: 256}, Static::Validators::AssetDimensions.expected_dimensions_for("avatar.webp"))
    assert_equal({width: 1300, height: 350}, Static::Validators::AssetDimensions.expected_dimensions_for("banner.webp"))
    assert_equal({width: 600, height: 350}, Static::Validators::AssetDimensions.expected_dimensions_for("card.webp"))
    assert_equal({width: 615, height: 350}, Static::Validators::AssetDimensions.expected_dimensions_for("featured.webp"))
    assert_equal({width: 600, height: 350}, Static::Validators::AssetDimensions.expected_dimensions_for("poster.webp"))
  end

  test "returns expected dimensions for sticker and stamp variants" do
    assert_equal({width: 350, height: 350}, Static::Validators::AssetDimensions.expected_dimensions_for("sticker.webp"))
    assert_equal({width: 350, height: 350}, Static::Validators::AssetDimensions.expected_dimensions_for("sticker-2.webp"))
    assert_equal({width: 512, height: 512}, Static::Validators::AssetDimensions.expected_dimensions_for("stamp.webp"))
    assert_equal({width: 512, height: 512}, Static::Validators::AssetDimensions.expected_dimensions_for("stamp-gold.webp"))
  end

  test "ignores unknown assets" do
    assert_nil Static::Validators::AssetDimensions.expected_dimensions_for("logo.webp")
    assert_nil Static::Validators::AssetDimensions.expected_dimensions_for("notes.txt")
  end

  test "returns empty errors for an asset with matching dimensions" do
    validator = Static::Validators::AssetDimensions.new(file_path: VALID_ASSET_FILE)
    assert_empty validator.errors
  end

  test "returns an error for a known asset with mismatched dimensions" do
    with_temp_asset("avatar.webp") do |file_path|
      validator = Static::Validators::AssetDimensions.new(file_path: file_path)
      original_method = Static::Validators::AssetDimensions.method(:dimensions_for)

      Static::Validators::AssetDimensions.define_singleton_method(:dimensions_for) do |path|
        if path.to_s == file_path
          {width: 128, height: 128}
        else
          original_method.call(path)
        end
      end

      begin
        assert_equal 1, validator.errors.size
        assert_match(/128x128/, validator.errors.first.to_h["message"])
        assert_match(/256x256/, validator.errors.first.to_h["message"])
        assert validator.errors.all? { |error| error.is_a?(Static::Validators::Error) }
      ensure
        Static::Validators::AssetDimensions.define_singleton_method(:dimensions_for, original_method)
      end
    end
  end

  test "scans all real event assets into validator errors" do
    errors = Dir.glob(Rails.root.join("app/assets/images/events/**/*.webp")).flat_map do |file_path|
      Static::Validators::AssetDimensions.new(file_path: file_path).errors
    end

    assert errors.all? { |error| error.is_a?(Static::Validators::Error) }
  end

  test "dimensions_for with real image" do
    assert_equal({width: 256, height: 256}, Static::Validators::AssetDimensions.dimensions_for(VALID_ASSET_FILE))
  end

  private

  def with_temp_asset(filename)
    dir = Dir.mktmpdir
    file_path = File.join(dir, filename)
    File.write(file_path, "")
    yield file_path
  ensure
    FileUtils.rm_rf(dir)
  end
end
