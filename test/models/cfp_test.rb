require "test_helper"

class CFPTest < ActiveSupport::TestCase
  setup do
    @cfp = cfps(:one)
  end

  test "with_dates scope includes cfps with both open and close dates" do
    assert_includes CFP.with_dates, @cfp
  end

  test "with_dates scope excludes cfps missing open_date" do
    @cfp.update_column(:open_date, nil)

    assert_not_includes CFP.with_dates, @cfp
  end

  test "with_dates scope excludes cfps missing close_date" do
    @cfp.update_column(:close_date, nil)

    assert_not_includes CFP.with_dates, @cfp
  end
end
