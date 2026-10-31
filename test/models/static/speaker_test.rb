require "test_helper"

class Static::SpeakerTest < ActiveSupport::TestCase
  include StaticSpeakersSandbox

  test "find_by name" do
    speaker = Static::Speaker.find_by(name: "Aaron Patterson")

    assert_instance_of Static::Speaker, speaker
    assert_equal "tenderlove", speaker.github
  end

  test "find_by name falls back to aliases" do
    speaker = Static::Speaker.all.find { |record| Array(record["aliases"]).first&.dig("name") }
    speaker_name = speaker.name
    alias_name = speaker["aliases"].first["name"]

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
    assert_includes reloaded["aliases"], {"name" => "Tenderlove Patterson", "slug" => "tenderlove-patterson"}
  end

  test "social_handle? is true when any social field is present" do
    assert Static::Speaker.find_by(name: "Aaron Patterson").social_handle?
    assert_not Static::Speaker.new(name: "Nobody").social_handle?
  end

  test "importing a renamed speaker without a GitHub handle renames their user and keeps the old slug as an alias" do
    user = User.create!(name: "Tom Heina", slug: "tom-heina")

    Dir.mktmpdir do |dir|
      path = File.join(dir, "speakers.yml")
      File.write(path, %(---\n- name: "Tom Heinan"\n  github: ""\n  slug: "tom-heinan"\n  aliases:\n    - name: "Tom Heina"\n      slug: "tom-heina"\n))

      Static::Speaker.with_path(path) { Static::Speaker.all.first.import!(index: false) }
    end

    assert_equal ["Tom Heinan", "tom-heinan"], [user.reload.name, user.slug]
    assert_equal user, User.find_by_slug_or_alias("tom-heina")
    assert_equal 1, User.where(name: ["Tom Heina", "Tom Heinan"]).count
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

  test "import_all! imports the remaining speakers and then raises when one fails to save" do
    invalid = ActiveRecord::RecordInvalid.new(::User.new)
    imported = []
    speakers = %w[First Broken Last].map do |name|
      speaker = Struct.new(:name, :github).new(name, name.downcase)
      speaker.define_singleton_method(:import!) { |**| (name == "Broken") ? raise(invalid) : imported << name && nil }
      speaker
    end

    Static::Speaker.stub(:all, speakers) do
      error = assert_raises(Static::ImportError) { Static::Speaker.import_all!(index: false) }

      assert_match "Broken", error.message
    end

    assert_equal %w[First Last], imported
  end
end
