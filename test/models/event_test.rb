require "test_helper"

class EventTest < ActiveSupport::TestCase
  setup do
    @organisation = organisations(:railsconf)
    @organisation.update(website: "https://railsconf.org")
  end

  test "validates the country code " do
    assert Event.new(name: "test", country_code: "NL", organisation: @organisation).valid?
    assert Event.new(name: "test", country_code: "AU", organisation: @organisation).valid?
    refute Event.new(name: "test", country_code: "France", organisation: @organisation).valid?
  end

  test "allows nil country code" do
    assert Event.new(name: "test", country_code: nil, organisation: @organisation).valid?
  end

  test "returns event website if present" do
    event = Event.new(name: "test", organisation: @organisation, website: "https://event-website.com")
    assert_equal "https://event-website.com", event.website
  end

  test "returns organisation website if event website is not present" do
    event = Event.new(name: "test", organisation: @organisation, website: nil)
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
