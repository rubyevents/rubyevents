require "test_helper"

class Ahoy::VisitTest < ActiveSupport::TestCase
  test "should respond to rollup methods" do
    assert_respond_to Ahoy::Visit, :rollup
    assert_respond_to Ahoy::Visit, :rollup_default_column
  end

  test "should set rollup default column" do
    Ahoy::Visit.rollup_default_column(:started_at)
    assert_equal :started_at, Ahoy::Visit.rollup_column
  end

  test "rollup method should perform aggregation" do
    @visit = Ahoy::Visit.create!(started_at: Time.now)
    @visit_2 = Ahoy::Visit.create!(started_at: Time.now - 1.day)
    @visit_3 = Ahoy::Visit.create!(started_at: Time.now - 2.days)
    @visit_3_2 = Ahoy::Visit.create!(started_at: Time.now - 2.days)

    result = Ahoy::Visit.rollup(:some_metric, interval: "day")
    assert_nil result # Since rollup method returns nil
    assert_equal 3, Rollup.count
    assert_equal 3, Rollup.series("some_metric", interval: "day").count
    assert_equal [2, 1, 1], Rollup.series("some_metric", interval: "day").values
  end

  test "rollup method should perform aggregation with group" do
    @visit = Ahoy::Visit.create!(started_at: Time.now, browser: "Chrome")
    @visit_2 = Ahoy::Visit.create!(started_at: Time.now - 1.day, browser: "Firefox")
    @visit_3 = Ahoy::Visit.create!(started_at: Time.now - 2.days, browser: "Safari")
    @visit_3_2 = Ahoy::Visit.create!(started_at: Time.now - 2.days, browser: "Safari")

    result = Ahoy::Visit.group(:browser).rollup(:some_metric, interval: "day")
    assert_nil result # Since rollup method returns nil
    assert_equal 9, Rollup.count
    assert_equal [2, 1, 1], Rollup.series("some_metric", interval: "day").values
    assert_equal [2, 0, 0], Rollup.with_dimensions(browser: "Safari").series("some_metric", interval: "day").values
    assert_equal [0, 1, 0], Rollup.with_dimensions(browser: "Firefox").series("some_metric", interval: "day").values
    assert_equal [2, 1, 0], Rollup.with_dimensions(browser: ["Firefox", "Safari"]).series("some_metric", interval: "day").values
  end
end
