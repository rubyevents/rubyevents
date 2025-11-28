require "test_helper"

class EventTest < ActiveSupport::TestCase
  setup do
    @series = event_series(:railsconf)
    @series.update(website: "https://railsconf.org")
  end

  test "validates the country code " do
    assert Event.new(name: "test", country_code: "NL", series: @series).valid?
    assert Event.new(name: "test", country_code: "AU", series: @series).valid?
    refute Event.new(name: "test", country_code: "France", series: @series).valid?
  end

  test "allows nil country code" do
    assert Event.new(name: "test", country_code: nil, series: @series).valid?
  end

  test "returns event website if present" do
    event = Event.new(name: "test", series: @series, website: "https://event-website.com")
    assert_equal "https://event-website.com", event.website
  end

  test "returns event series website if event website is not present" do
    event = Event.new(name: "test", series: @series, website: nil)
    assert_equal "https://railsconf.org", event.website
  end

  test "don't create a unique slug in case of collison" do
    event = Event.create(name: "test")
    assert_equal "test", event.slug

    event = Event.create(name: "test")
    assert_equal "test", event.slug
    refute event.valid?
  end
end
