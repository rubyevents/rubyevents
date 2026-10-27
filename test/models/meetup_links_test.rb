# frozen_string_literal: true

require "test_helper"

class MeetupLinksTest < ActiveSupport::TestCase
  test "field_for names the platform of a link" do
    assert_equal "meetup", MeetupLinks.field_for("https://www.meetup.com/lrug/events/312345678/")
    assert_equal "luma", MeetupLinks.field_for("https://lu.ma/b8jn0glb")
    assert_equal "luma", MeetupLinks.field_for("https://luma.com/sfruby")
    assert_equal "kommunity", MeetupLinks.field_for("https://kommunity.com/ruby-turkiye/events/abc")
  end

  test "field_for treats any other link as the website" do
    assert_equal "website", MeetupLinks.field_for("https://lrug.org/meetings/2026/october")
    assert_equal "website", MeetupLinks.field_for("not a url")
  end

  test "EVENT_URLS match a single meetup's page" do
    assert_match MeetupLinks::EVENT_URLS["meetup"], "https://www.meetup.com/lrug/events/312345678/"
    assert_no_match MeetupLinks::EVENT_URLS["meetup"], "https://www.meetup.com/lrug/"
  end
end
