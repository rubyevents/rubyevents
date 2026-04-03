require "test_helper"

class CFPTest < ActiveSupport::TestCase
  test "days_remaining return nil without close_date" do
    cfp = CFP.new(close_date: nil)
    assert_nil cfp.days_remaining
  end

  test "days_remaining return nil when closed" do
    cfp = CFP.new(close_date: 1.day.ago)
    assert_nil cfp.days_remaining
  end

  test "days_remaining return 3 days" do
    cfp = CFP.new(close_date: 3.days.from_now)
    assert_equal 3, cfp.days_remaining
  end

  test "days_until_open return nil without open_date" do
    cfp = CFP.new(open_date: nil)
    assert_nil cfp.days_until_open
  end

  test "days_until_open return nil if opened" do
    cfp = CFP.new(open_date: 1.day.ago, close_date: nil)
    assert_nil cfp.days_until_open
  end

  test "days_until_open return nil if past" do
    cfp = CFP.new(open_date: 10.days.ago, close_date: 5.days.ago)
    assert_nil cfp.days_until_open
  end

  test "days_until_open return 5 days" do
    cfp = CFP.new(open_date: 5.days.from_now)
    assert_equal 5, cfp.days_until_open
  end

  test "days_since_close return nil without close_date" do
    cfp = CFP.new(close_date: nil)
    assert_nil cfp.days_since_close
  end

  test "days_since_close return nil if future" do
    cfp = CFP.new(close_date: 5.days.from_now)
    assert_nil cfp.days_since_close
  end

  test "days_since_close return nil if open" do
    cfp = CFP.new(open_date: 1.day.ago, close_date: 5.days.from_now)
    assert_nil cfp.days_since_close
  end

  test "days_since_close return 3 days" do
    cfp = CFP.new(close_date: 4.days.ago)
    assert_equal 4, cfp.days_since_close
  end
end
