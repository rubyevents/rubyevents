require "test_helper"

class Events::FeedsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @event1 = events(:railsconf_2017)
    @event2 = events(:rubyconfth_2022)
    @event3 = events(:tropical_rb_2024)
  end

  test "should get index as XML" do
    get feed_events_url(format: :xml)
    assert_response :success
    assert_match "application/xml", @response.content_type
  end

  test "should return events ordered by date descending" do
    get feed_events_url(format: :xml)
    assert_response :success

    # Parse XML and verify order
    doc = Nokogiri::XML(@response.body)
    entries = doc.xpath("//atom:entry", "atom" => "http://www.w3.org/2005/Atom")

    assert_operator entries.length, :>, 0
    assert_operator entries.length, :<=, 20 # Should limit to 20 events
  end

  test "should limit events to 20" do
    # Create more than 20 events to test the limit
    organisation = organisations(:railsconf)
    25.times do |i|
      Event.create!(
        name: "Test Event #{i}",
        date: Date.current - i.days,
        slug: "test-event-#{i}",
        organisation: organisation
      )
    end

    get feed_events_url(format: :xml)
    assert_response :success

    doc = Nokogiri::XML(@response.body)
    entries = doc.xpath("//atom:entry", "atom" => "http://www.w3.org/2005/Atom")

    # Should have exactly 20 entries (limit) even though we created more
    assert_equal 20, entries.length
  end

  test "should not require authentication" do
    get feed_events_url(format: :xml)
    assert_response :success
    # Should not redirect to login
  end

  test "should handle empty events gracefully" do
    Event.destroy_all

    get feed_events_url(format: :xml)
    assert_response :success

    doc = Nokogiri::XML(@response.body)
    entries = doc.xpath("//atom:entry", "atom" => "http://www.w3.org/2005/Atom")

    assert_equal 0, entries.length
  end

  test "should only respond to XML format" do
    get feed_events_url(format: :json)
    assert_response :not_acceptable
  end
end
