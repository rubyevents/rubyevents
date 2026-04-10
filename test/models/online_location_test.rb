# frozen_string_literal: true

require "test_helper"

class OnlineLocationTest < ActiveSupport::TestCase
  test "instance returns singleton instance" do
    instance1 = OnlineLocation.instance
    instance2 = OnlineLocation.instance

    assert_same instance1, instance2
  end

  test "name returns Online" do
    location = OnlineLocation.instance

    assert_equal "online", location.name
  end

  test "slug returns online" do
    location = OnlineLocation.instance

    assert_equal "online", location.slug
  end

  test "emoji_flag returns globe emoji" do
    location = OnlineLocation.instance

    assert_equal location.emoji_flag, location.emoji_flag
  end

  test "path returns online path" do
    location = OnlineLocation.instance

    assert_equal "/locations/online", location.path
  end

  test "past_path returns online past path" do
    location = OnlineLocation.instance

    assert_equal "/locations/online/past", location.past_path
  end

  test "users_path returns nil" do
    location = OnlineLocation.instance

    assert_nil location.users_path
  end

  test "cities_path returns nil" do
    location = OnlineLocation.instance

    assert_nil location.cities_path
  end

  test "stamps_path returns nil" do
    location = OnlineLocation.instance

    assert_nil location.stamps_path
  end

  test "map_path returns nil" do
    location = OnlineLocation.instance

    assert_nil location.map_path
  end

  test "has_routes? returns true" do
    location = OnlineLocation.instance

    assert location.has_routes?
  end

  test "events returns not geocoded events" do
    location = OnlineLocation.instance

    assert location.events.is_a?(ActiveRecord::Relation)
  end

  test "users returns empty relation" do
    location = OnlineLocation.instance

    assert_equal 0, location.users.count
  end

  test "stamps returns empty array" do
    location = OnlineLocation.instance

    assert_equal [], location.stamps
  end

  test "users_count returns 0" do
    location = OnlineLocation.instance

    assert_equal 0, location.users_count
  end

  test "geocoded? returns false" do
    location = OnlineLocation.instance

    refute location.geocoded?
  end

  test "coordinates returns nil" do
    location = OnlineLocation.instance

    assert_nil location.coordinates
  end

  test "to_coordinates returns nil" do
    location = OnlineLocation.instance

    assert_nil location.to_coordinates
  end

  test "bounds returns nil" do
    location = OnlineLocation.instance

    assert_nil location.bounds
  end

  test "to_location returns Location with virtual events text" do
    location = OnlineLocation.instance
    to_location = location.to_location

    assert_kind_of Location, to_location
    assert_equal "online", to_location.to_text
  end
end
