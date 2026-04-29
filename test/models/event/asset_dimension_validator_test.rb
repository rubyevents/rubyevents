require "test_helper"
require "fileutils"
require "tmpdir"

class Event::AssetDimensionValidatorTest < ActiveSupport::TestCase
  test "returns expected dimensions for core assets" do
    assert_equal({width: 256, height: 256}, Event::AssetDimensionValidator.expected_dimensions_for("avatar.webp"))
    assert_equal({width: 1300, height: 350}, Event::AssetDimensionValidator.expected_dimensions_for("banner.webp"))
    assert_equal({width: 600, height: 350}, Event::AssetDimensionValidator.expected_dimensions_for("card.webp"))
    assert_equal({width: 615, height: 350}, Event::AssetDimensionValidator.expected_dimensions_for("featured.webp"))
    assert_equal({width: 600, height: 350}, Event::AssetDimensionValidator.expected_dimensions_for("poster.webp"))
  end

  test "returns expected dimensions for sticker and stamp variants" do
    assert_equal({width: 350, height: 350}, Event::AssetDimensionValidator.expected_dimensions_for("sticker.webp"))
    assert_equal({width: 350, height: 350}, Event::AssetDimensionValidator.expected_dimensions_for("sticker-2.webp"))
    assert_equal({width: 512, height: 512}, Event::AssetDimensionValidator.expected_dimensions_for("stamp.webp"))
    assert_equal({width: 512, height: 512}, Event::AssetDimensionValidator.expected_dimensions_for("stamp-gold.webp"))
  end

  test "ignores unknown assets" do
    assert_nil Event::AssetDimensionValidator.expected_dimensions_for("logo.webp")
    assert_nil Event::AssetDimensionValidator.expected_dimensions_for("notes.txt")
  end

  test "reports warnings only for known assets with mismatched dimensions" do
    Dir.mktmpdir do |dir|
      image_root = Pathname.new(dir)
      avatar_path = image_root.join("series", "event", "avatar.webp")
      sticker_path = image_root.join("series", "event", "sticker-2.webp")
      unknown_path = image_root.join("series", "event", "logo.webp")

      [avatar_path, sticker_path, unknown_path].each do |path|
        FileUtils.mkdir_p(path.dirname)
        File.write(path, "")
      end

      dimensions_by_path = {
        avatar_path.to_s => {width: 128, height: 128},
        sticker_path.to_s => {width: 350, height: 350},
        unknown_path.to_s => {width: 100, height: 100}
      }

      validator = Event::AssetDimensionValidator
      original_method = validator.method(:dimensions_for)

      validator.define_singleton_method(:dimensions_for) do |path|
        dimensions_by_path.fetch(path.to_s)
      end

      begin
        warnings = Event::AssetDimensionValidator.warnings(image_root: image_root)

        assert_equal 1, warnings.size
        assert_equal "series/event/avatar.webp", warnings.first[:path]
        assert_equal({width: 128, height: 128}, warnings.first[:actual])
        assert_equal({width: 256, height: 256}, warnings.first[:expected])
      ensure
        validator.define_singleton_method(:dimensions_for, original_method)
      end
    end
  end
end
