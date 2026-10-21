require "test_helper"

class Static::SpeakerTest < ActiveSupport::TestCase
  include StaticSpeakersSandbox

  test "find_by name" do
    speaker = Static::Speaker.find_by(name: "Aaron Patterson")

    assert_instance_of Static::Speaker, speaker
    assert_equal "tenderlove", speaker.github
  end

  test "find_by name falls back to aliases" do
    speaker = Static::Speaker.all.find { |record| record.alias_names.any? }
    speaker_name = speaker.name
    alias_name = speaker.alias_names.first

    assert_equal speaker_name, Static::Speaker.find_by(name: alias_name).name
  end

  test "find_by slug and github" do
    assert_equal "Aaron Patterson", Static::Speaker.find_by(slug: "aaron-patterson").name
    assert_equal "Aaron Patterson", Static::Speaker.find_by(github: "tenderlove").name
  end

  test "find_by name falls back to the GitHub handle" do
    assert_equal "Aaron Patterson", Static::Speaker.find_by(name: "tenderlove").name
    assert_equal "Aaron Patterson", Static::Speaker.find_by(name: "TenderLove").name
  end

  test "import! creates redirect aliases for slugs" do
    Static::Speaker.find_by(name: "Aaron Patterson").add_slug("aaron-patterson-old")
    Static::Speaker.save!

    speaker = Static::Speaker.find_by(name: "Aaron Patterson")
    assert_includes speaker.redirect_slugs, "aaron-patterson-old"

    user = speaker.import!(index: false) || User.find_by(slug: speaker.slug)

    assert_equal user, User.find_by_slug_or_alias("aaron-patterson-old")
    assert_equal user, User.find_by_slug_or_alias(speaker.slug)
  end

  test "find_by name ignores case and surrounding whitespace" do
    assert_equal "Aaron Patterson", Static::Speaker.find_by(name: "aaron patterson").name
    assert_equal "Aaron Patterson", Static::Speaker.find_by(name: " AARON PATTERSON ").name
  end

  test "known_reference? ignores case and surrounding whitespace" do
    assert Static::Speaker.known_reference?("aaron patterson")
    assert Static::Speaker.known_reference?(" Aaron Patterson ")
  end

  test "canonical_name resolves aliases, casing, and GitHub handles to the speaker name" do
    assert_equal "Yatish Mehta", Static::Speaker.canonical_name("yatish-asana")
    assert_equal "Aaron Patterson", Static::Speaker.canonical_name(" aaron patterson ")
    assert_equal "Aaron Patterson", Static::Speaker.canonical_name("tenderlove")
    assert_equal "Nobody Known", Static::Speaker.canonical_name(" Nobody Known ")
  end

  test "find_by name falls back to additional GitHub handles" do
    speaker = Static::Speaker.find_by(name: "Yatish Mehta")
    assert_includes speaker.all_github_handles, "yatish-asana"

    assert_equal "Yatish Mehta", Static::Speaker.find_by(name: "yatish-asana").name
    assert_equal "Yatish Mehta", Static::Speaker.find_by_github_handle("Yatish-Asana").name
    assert Static::Speaker.known_reference?("yatish-asana")
  end

  test "known_reference? includes GitHub handles" do
    assert Static::Speaker.known_reference?("Aaron Patterson")
    assert Static::Speaker.known_reference?("tenderlove")
    assert_not Static::Speaker.known_reference?("Nobody #{SecureRandom.hex(4)}")
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
    assert_not_includes File.read(Rails.root.join("data/speakers.yml")), name
  end

  test "find_by with several lookup keys prefers slug, then github, then name" do
    assert_equal "Aaron Patterson", Static::Speaker.find_by(name: "Nobody", github: "tenderlove").name
    assert_equal "Aaron Patterson", Static::Speaker.find_by(name: " Aaron Patterson ").name
  end

  test "upsert updates an existing speaker and returns the record" do
    speaker = Static::Speaker.upsert(name: "Aaron Patterson", github: "", website: " https://tenderlovemaking.com ")

    assert_instance_of Static::Speaker, speaker
    assert_equal "tenderlove", speaker.github
    assert_equal "https://tenderlovemaking.com", speaker.website
    assert Static::Speaker.changed?

    Static::Speaker.save!

    assert_includes File.read(@sandboxed_speakers_file.path), "https://tenderlovemaking.com"
  end

  test "add raises on blank and duplicate speakers" do
    assert_raises(Static::Speaker::InvalidSpeakerError) { Static::Speaker.add(name: " ") }
    assert_raises(Static::Speaker::DuplicateSpeakerError) { Static::Speaker.add(name: "Aaron Patterson") }
    assert_raises(Static::Speaker::DuplicateSpeakerError) { Static::Speaker.add(name: "Someone Else", github: "tenderlove") }
  end

  test "add_alias and assign edit a speaker" do
    speaker = Static::Speaker.find_by(name: "Aaron Patterson")

    speaker.add_alias(name: "Tenderlove Patterson")
    speaker.assign(twitter: "  ", mastodon: " https://ruby.social/@tenderlove ")
    speaker.save!

    reloaded = Static::Speaker.find_by(name: "Tenderlove Patterson")
    assert_equal "Aaron Patterson", reloaded.name
    assert_equal "https://ruby.social/@tenderlove", reloaded.mastodon
    assert_includes reloaded.alias_names, "Tenderlove Patterson"
  end

  test "social_handle? is true when any social field is present" do
    assert Static::Speaker.find_by(name: "Aaron Patterson").social_handle?
    assert_not Static::Speaker.new(name: "Nobody").social_handle?
  end

  test "with_path points the model at another file temporarily" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "speakers.yml")
      File.write(path, %(---\n- name: "Only Speaker"\n  github: ""\n  slug: "only-speaker"\n))

      Static::Speaker.with_path(path) do
        assert_equal ["Only Speaker"], Static::Speaker.all.names
      end

      assert_operator Static::Speaker.count, :>, 1
    end
  end
end
