require "test_helper"

class SocialProfileTest < ActiveSupport::TestCase
  test "sociable association" do
    speaker = Speaker.create(name: "jogn")
    social_profile = SocialProfile.create(sociable: speaker, provider: :twitter, value: "john")

    assert_equal social_profile.value, speaker.twitter
    assert_equal social_profile.sociable, speaker
  end

  test "normalizes Twitter with URL" do
    assert_equal "username", SocialProfile.normalize_value_for(:twitter, "https://twitter.com/username")
  end

  test "normalizes Twitter with handle" do
    assert_equal "username", SocialProfile.normalize_value_for(:twitter, "username")
  end

  test "normalizes X.com" do
    assert_equal "username", SocialProfile.normalize_value_for(:twitter, "https://x.com/username")
  end

  test "normalizes bsky (bsky.social)" do
    assert_equal "username.bsky.social", SocialProfile.normalize_value_for(:bsky, "https://bsky.app/profile/username.bsky.social")
  end

  test "normalizes bsky with handle (bsky.social)" do
    assert_equal "username.bsky.social", SocialProfile.normalize_value_for(:bsky, "username.bsky.social")
  end

  test "normalizes bsky (custom domain)" do
    assert_equal "username.dev", SocialProfile.normalize_value_for(:bsky, "https://bsky.app/profile/username.dev")
  end

  test "normalizes bsky with handle (custom domain)" do
    assert_equal "username.dev", SocialProfile.normalize_value_for(:bsky, "username.dev")
  end

  test "normaliezs mastodon (mastodon.social)" do
    assert_equal "https://mastodon.social/@username", SocialProfile.normalize_value_for(:mastodon, "https://mastodon.social/@username")
  end

  test "normalizes mastodon with handle (mastodon.social)" do
    assert_equal "https://mastodon.social/@username", SocialProfile.normalize_value_for(:mastodon, "@username@mastodon.social")
  end

  test "normalizes mastodon (ruby.social)" do
    assert_equal "https://ruby.social/@username", SocialProfile.normalize_value_for(:mastodon, "https://ruby.social/@username")
  end

  test "normalizes mastodon with handle (ruby.social)" do
    assert_equal "https://ruby.social/@username", SocialProfile.normalize_value_for(:mastodon, "@username@ruby.social")
  end

  test "normalizes linkedin with url" do
    assert_equal "username", SocialProfile.normalize_value_for(:linkedin, "https://linkedin.com/in/username")
  end

  test "normalizes linkedin with slug" do
    assert_equal "username", SocialProfile.normalize_value_for(:linkedin, "username")
  end

  test "doesnt normalize website" do
    assert_equal "https://foo.bar", SocialProfile.normalize_value_for(:website, "https://foo.bar")
  end

  test "generates url" do
    assert_equal "https://twitter.com/jim", social_profiles(:twitter).url
    assert_equal "https://linkedin.com/in/jim", social_profiles(:linkedin).url
    assert_equal "https://bsky.app/profile/jim", social_profiles(:bsky).url
    assert_equal "https://ruby.social/@jim", social_profiles(:mastodon).url
    assert_equal "https://speakerdeck.com/jim", social_profiles(:speakerdeck).url
    assert_equal "https://jim.com", social_profiles(:website).url
  end
end
