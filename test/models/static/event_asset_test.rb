# frozen_string_literal: true

require "test_helper"

class Static::EventAssetTest < ActiveSupport::TestCase
  DEFAULT_ASSETS = Rails.root.join("app/assets/images/events/default")

  setup do
    @root = Dir.mktmpdir
    @previous_root = Static::EventAsset.instance_variable_get(:@root)
    Static::EventAsset.root = @root
    Static::EventAsset.unload!

    write_data("data/testconf/series.yml")
    write_data("data/testconf/testconf-2025/event.yml")
  end

  teardown do
    Static::EventAsset.root = @previous_root
    Static::EventAsset.unload!
    FileUtils.rm_rf(@root) if @root
  end

  test "expected_dimensions_for returns the dimensions of core assets" do
    assert_equal({width: 256, height: 256}, Static::EventAsset.expected_dimensions_for("avatar"))
    assert_equal({width: 1300, height: 350}, Static::EventAsset.expected_dimensions_for("banner"))
    assert_equal({width: 600, height: 350}, Static::EventAsset.expected_dimensions_for("card"))
    assert_equal({width: 615, height: 350}, Static::EventAsset.expected_dimensions_for("featured"))
    assert_equal({width: 600, height: 350}, Static::EventAsset.expected_dimensions_for("poster"))
  end

  test "expected_dimensions_for returns the dimensions of sticker and stamp variants" do
    assert_equal({width: 350, height: 350}, Static::EventAsset.expected_dimensions_for("sticker"))
    assert_equal({width: 350, height: 350}, Static::EventAsset.expected_dimensions_for("sticker-2"))
    assert_equal({width: 512, height: 512}, Static::EventAsset.expected_dimensions_for("stamp"))
    assert_equal({width: 512, height: 512}, Static::EventAsset.expected_dimensions_for("stamp-gold"))
  end

  test "expected_dimensions_for ignores unknown assets" do
    assert_nil Static::EventAsset.expected_dimensions_for("logo")
  end

  test "does not flag an asset with the expected dimensions" do
    asset = write_asset("testconf/testconf-2025/avatar.webp", from: "avatar.webp")

    assert asset.valid?(:lint), asset.errors.full_messages.join(", ")
  end

  test "flags a known asset with other dimensions" do
    asset = write_asset("testconf/testconf-2025/avatar.webp", from: "banner.webp")

    assert_not asset.valid?(:lint)
    assert_equal ["Asset dimensions are 1300x350, expected 256x256"], asset.errors.full_messages
    assert_equal asset.file_path, asset.error_file_path(asset.errors.first)
  end

  test "does not check the dimensions of unknown or unreadable assets" do
    assert write_asset("testconf/testconf-2025/logo.webp", from: "banner.webp").valid?(:lint)
    assert write_asset("testconf/testconf-2025/card.webp").valid?(:lint)
  end

  test "does not flag assets of an existing event, a series default or the global default" do
    assets = [
      write_asset("testconf/testconf-2025/featured.webp"),
      write_asset("testconf/default/featured.webp"),
      write_asset("testconf/featured.webp"),
      write_asset("default/featured.webp")
    ]

    assert assets.all? { |asset| asset.valid?(:lint) }
  end

  test "flags assets of an unknown event" do
    asset = write_asset("testconf/testconf-1999/featured.webp")

    assert_not asset.valid?(:lint)
    assert_equal ["Asset does not belong to any event, there is no matching folder in data/testconf/testconf-1999"], asset.errors.full_messages
  end

  test "flags assets of an unknown series" do
    asset = write_asset("nosuchconf/default/featured.webp")

    assert_not asset.valid?(:lint)
    assert_equal ["Asset does not belong to any event, there is no matching folder in data/nosuchconf/default"], asset.errors.full_messages
  end

  test "all finds the event assets under the root" do
    write_asset("testconf/testconf-2025/featured.webp")
    write_asset("default/avatar.webp")

    assert_equal [%w[default], %w[testconf testconf-2025]], Static::EventAsset.all.map(&:folders)
  end

  test "real event assets belong to an event and have the expected dimensions" do
    Static::EventAsset.root = @previous_root
    Static::EventAsset.unload!

    assert Static::EventAsset.all.any?

    errors = Static::EventAsset.all.reject { |asset| asset.valid?(:lint) }.flat_map do |asset|
      asset.errors.full_messages.map { |message| "#{asset.file_path}: #{message}" }
    end

    assert_empty errors
  end

  private

  def write_data(path)
    FileUtils.mkdir_p(File.dirname(File.join(@root, path)))
    File.write(File.join(@root, path), "---\nname: TestConf\n")
  end

  def write_asset(path, from: nil)
    file_path = File.join(@root, "app/assets/images/events", path)
    FileUtils.mkdir_p(File.dirname(file_path))
    from ? FileUtils.cp(DEFAULT_ASSETS.join(from), file_path) : FileUtils.touch(file_path)

    Static::EventAsset.new(file_path)
  end
end
