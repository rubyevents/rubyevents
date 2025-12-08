require "test_helper"

class User::ProfilesTest < ActiveSupport::TestCase
  test "enhance_with_github with GitHub profile" do
    VCR.use_cassette("user/enhance_profile_job_test") do
      user = User.create!(name: "Aaron Patterson", github_handle: "tenderlove", email: "aaron@tenderlove.com", password: "password")

      user.profiles.enhance_with_github
      user.reload

      assert_equal "tenderlove", user.github_handle
      assert_equal "tenderlove", user.twitter
      assert_equal "tenderlove.dev", user.bsky
      assert_equal "https://mastodon.social/@tenderlove", user.mastodon

      assert user.bio?
      assert user.github_metadata?

      assert_equal 3124, user.github_metadata.dig("profile", "id")
      assert_equal "https://twitter.com/tenderlove", user.github_metadata.dig("socials", 0, "url")
    end
  end

  test "enhance_with_github with no GitHub handle" do
    user = User.create!(name: "Nathan Bibler", email: "nathan@rubyevents.org", password: "password")

    user.profiles.enhance_with_github
    user.reload

    assert user.github_handle.blank?
    assert_equal({}, user.github_metadata)
  end
end
