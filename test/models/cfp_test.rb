require "test_helper"

class CFPTest < ActiveSupport::TestCase
  setup do
    @cfp = cfps(:one)
  end

  test "to_ical returns an Icalendar::Event" do
    assert_kind_of Icalendar::Event, @cfp.to_ical
  end

  test "to_ical sets uid with CFP prefix" do
    assert_equal "RUBYEVENTS-CFP-#{@cfp.id}", @cfp.to_ical.uid.to_s
  end

  test "to_ical sets summary with event name and cfp name" do
    assert_equal "Future Conference - Future Conference 2024 CFP", @cfp.to_ical.summary.to_s
  end

  test "to_ical uses generic summary when cfp has no name" do
    @cfp.update!(name: nil)

    assert_equal "Future Conference - Call for Proposals", @cfp.to_ical.summary.to_s
  end

  test "to_ical sets dtstart to open_date and dtend to close_date plus one day" do
    ical = @cfp.to_ical.to_ical

    assert_includes ical, "DTSTART;VALUE=DATE:#{@cfp.open_date.strftime("%Y%m%d")}"
    assert_includes ical, "DTEND;VALUE=DATE:#{(@cfp.close_date + 1.day).strftime("%Y%m%d")}"
  end

  test "to_ical sets url to cfp link" do
    assert_equal "https://www.futureconference.com/cfp", @cfp.to_ical.url.to_s
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
