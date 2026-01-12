require "test_helper"

class RollupTest < ActiveSupport::TestCase
  def setup
    @rollup = Rollup.new(name: "Test Rollup", interval: "day", time: Time.now)
  end

  test "should be valid with valid attributes" do
    assert @rollup.valid?
  end

  test "should require a name" do
    @rollup.name = nil
    assert_not @rollup.valid?
  end

  test "should require an interval" do
    @rollup.interval = nil
    assert_not @rollup.valid?
  end

  test "should require a time" do
    @rollup.time = nil
    assert_not @rollup.valid?
  end

  test "time_zone should return default time zone if not set" do
    assert Rollup.time_zone.is_a?(ActiveSupport::TimeZone)
  end

  test "series method should return correct series" do
    Rollup.create(name: "Test Rollup", interval: "day", time: Time.now, value: 1)
    series = Rollup.series("Test Rollup", interval: "day")
    assert_not_empty series
  end

  test "rename method should update rollup names" do
    Rollup.create!(name: "Old Name", interval: "day", time: Time.now)
    Rollup.rename("Old Name", "New Name")
    assert Rollup.where(name: "New Name").exists?
    assert_not Rollup.where(name: "Old Name").exists?
  end
end
