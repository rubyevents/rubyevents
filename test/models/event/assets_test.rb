require "test_helper"

class Event::AssetsTest < ActiveSupport::TestCase
  setup do
    @event = events(:future_conference)
  end

  test "base_path returns correct path" do
    expected = "events/#{@event.series.slug}/#{@event.slug}"
    assert_equal expected, @event.assets.base_path
  end

  test "default_path returns global default path" do
    assert_equal "events/default", @event.assets.default_path
  end

  test "default_series_path returns series default path" do
    expected = "events/#{@event.series.slug}/default"
    assert_equal expected, @event.assets.default_series_path
  end

  test "image_path_for falls back to global default when file does not exist" do
    result = @event.assets.image_path_for("nonexistent.webp")
    assert_equal "events/default/nonexistent.webp", result
  end

  test "image_path_if_exists returns nil when image does not exist" do
    result = @event.assets.image_path_if_exists("nonexistent.webp")
    assert_nil result
  end
end
