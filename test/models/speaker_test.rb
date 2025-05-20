require "test_helper"

class SpeakerTest < ActiveSupport::TestCase
  test "valid_website_url preserve the website url if already valid" do
    speaker = speakers(:one)
    speaker.create_website("https://www.google.com")
    assert_equal "https://www.google.com", speaker.valid_website_url
  end

  test "valid_website_url add https to the website if it is not present" do
    speaker = speakers(:one)
    speaker.create_website("www.google.com")
    assert_equal "https://www.google.com", speaker.valid_website_url
  end

  test "valid_website_url convert http to https" do
    speaker = speakers(:one)
    speaker.create_website("http://www.google.com")
    assert_equal "https://www.google.com", speaker.valid_website_url
  end

  test "valid_website_url returns # if website is blank" do
    speaker = speakers(:one)
    speaker.create_website("")
    assert_equal "#", speaker.valid_website_url
  end

  test "speaker user association" do
    speaker = speakers(:one)
    user = users(:one)
    user.update(github_handle: speaker.github)
    assert_equal user.github_handle, speaker.github
    assert_equal user, speaker.user
    assert_equal speaker, user.speaker
  end

  test "normalizes github with URL" do
    assert_equal "username", Speaker.new(github: "https://github.com/username").github
    assert_equal "username", Speaker.new(github: "http://github.com/username").github
    assert_equal "username", Speaker.new(github: "http://www.github.com/username").github
    assert_equal "username", Speaker.new(github: "@username").github
    assert_equal "username", Speaker.new(github: "github.com/username").github
  end

  test "assign_canonical_speaker! resets talks_count" do
    speaker = speakers(:yaroslav)
    assert speaker.talks_count.positive?
    assert speaker.github.present?

    speaker_2 = speakers(:one)
    assert_changes -> { speaker_2.reload.talks_count }, from: 0, to: speaker.talks_count do
      speaker.assign_canonical_speaker!(canonical_speaker: speaker_2)
    end

    assert speaker.reload.github.blank?
    assert_equal 0, speaker.reload.talks.count
    assert_equal 0, speaker.reload.talks_count
  end
end
