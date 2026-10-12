require "test_helper"

class Static::SpeakerTest < ActiveSupport::TestCase
  include StaticSpeakersSandbox

  test "find_by name" do
    speaker = Static::Speaker.find_by(name: "Aaron Patterson")

    assert_instance_of Static::Speaker, speaker
    assert_equal "tenderlove", speaker.github
  end

  test "find_by name falls back to aliases" do
    speaker_name, alias_name = Static::Speaker.speakers_file.entries.each do |entry|
      alias_name = Array(entry["aliases"]).first&.dig("name")
      break [entry["name"], alias_name] if alias_name
    end

    assert_equal speaker_name, Static::Speaker.find_by(name: alias_name).name
  end

  test "find_by slug and github" do
    assert_equal "Aaron Patterson", Static::Speaker.find_by(slug: "aaron-patterson").name
    assert_equal "Aaron Patterson", Static::Speaker.find_by(github: "tenderlove").name
  end

  test "find_by returns nil for unknown speakers" do
    assert_nil Static::Speaker.find_by(name: "Nobody #{SecureRandom.hex(4)}")
  end

  test "find_by falls back to a scan for non-indexed fields" do
    assert_equal "Aaron Patterson", Static::Speaker.find_by(twitter: Static::Speaker.find_by(name: "Aaron Patterson").twitter).name
  end

  test "find_or_create_by returns an existing speaker without writing" do
    assert_no_changes -> { File.read(@sandboxed_speakers_file.path) } do
      assert_equal "tenderlove", Static::Speaker.find_or_create_by(name: "Aaron Patterson").github
    end
  end

  test "find_or_create_by creates a missing speaker in the sandboxed file" do
    name = "Test Speaker #{SecureRandom.hex(4)}"

    speaker = Static::Speaker.find_or_create_by(name: name)

    assert_equal name, speaker.name
    assert_equal name.parameterize, speaker.slug
    assert_includes File.read(@sandboxed_speakers_file.path), name
    assert_not_includes File.read(Rails.root.join(Static::SpeakersFile::SPEAKERS_PATH)), name
  end
end
