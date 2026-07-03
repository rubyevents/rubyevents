require "test_helper"

class Event::StaticMetadataTest < ActiveSupport::TestCase
  setup do
    @event_with_assets = events(:railsconf_2017)
    @event_without_yaml = events(:future_conference)
  end

  test "featured_background returns value from YAML when present" do
    assert_equal "#FFFFFF", @event_with_assets.static_metadata.featured_background
  end

  test "featured_background returns default when no static repository exists" do
    assert_equal "black", @event_without_yaml.static_metadata.featured_background
  end

  test "featured_color returns value from YAML when present" do
    assert_equal "#5F1F7C", @event_with_assets.static_metadata.featured_color
  end

  test "featured_color returns default when no static repository exists" do
    assert_equal "white", @event_without_yaml.static_metadata.featured_color
  end

  test "banner_background returns value from YAML when present" do
    assert_equal "#C8EAF4", @event_with_assets.static_metadata.banner_background
  end

  test "banner_background returns default when no static repository exists" do
    assert_equal "#081625", @event_without_yaml.static_metadata.banner_background
  end
end
