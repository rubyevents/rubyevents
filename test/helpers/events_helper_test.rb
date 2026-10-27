require "test_helper"

class EventsHelperTest < ActionView::TestCase
  test "link_handle shows the part of a link that names the account" do
    assert_equal "amsterdam-rb", link_handle("meetup", "https://www.meetup.com/amsterdam-rb/")
    assert_equal "amsrb.org", link_handle("website", "https://www.amsrb.org/about")
    assert_equal "amsrb", link_handle("github", "https://github.com/amsrb")
    assert_equal "@amsrb", link_handle("twitter", "https://x.com/amsrb")
    assert_equal "@amsrb@ruby.social", link_handle("mastodon", "https://ruby.social/@amsrb")
    assert_equal "berlinrb.bsky.social", link_handle("bsky", "https://bsky.app/profile/berlinrb.bsky.social")
  end

  test "group_links_noun names the one link a group has, or says pages" do
    assert_equal "website", group_links_noun({"website" => "https://nwrug.org"})
    assert_equal "Meetup.com page", group_links_noun({"meetup" => "https://www.meetup.com/indyrb"})
    assert_equal "pages", group_links_noun({"luma" => "https://luma.com/sfruby", "website" => "https://sfruby.com"})
  end

  test "link_handle is nil without a path or for an invalid URL" do
    assert_nil link_handle("github", "https://github.com")
    assert_nil link_handle("github", "not a url with spaces")
  end
end
