require "test_helper"
require "#{Rails.root}/app/schemas/speaker_schema"
require "generators/speaker/speaker_generator"

class SpeakerGeneratorTest < Rails::Generators::TestCase
  tests SpeakerGenerator

  setup do
    self.class.destination Dir.mktmpdir("speaker_generator", Rails.root.join("tmp").to_s)
    FileUtils.mkdir_p(File.dirname(speakers_file_path))
    File.write(speakers_file_path, "--- []\n")
  end

  teardown { FileUtils.remove_entry(destination_root) }

  def speakers_file_path
    File.join(destination_root, "data", "speakers.yml")
  end

  def read_speakers
    Yerba.parse_file(speakers_file_path).to_a
  end

  def assert_valid_speakers_file
    errors = Static::Validators::Validator.speaker_validator_classes.flat_map do |validator|
      validator.new(file_path: speakers_file_path).errors
    end
    assert_empty errors, errors.map { |e| e.to_h["message"] }.join(", ")
  end

  test "adds a new speaker with all socials" do
    run_generator [
      "--name", "Jane Doe",
      "--github", "janedoe",
      "--slug", "jane-doe",
      "--twitter", "janedoe",
      "--website", "https://janedoe.example.com",
      "--mastodon", "https://ruby.social/@janedoe",
      "--bluesky", "janedoe.bsky.social",
      "--linkedin", "janedoe",
      "--speakerdeck", "janedoe"
    ]

    assert_file speakers_file_path do |content|
      assert_match(/- name: Jane Doe/, content)
      assert_match(/slug: jane-doe/, content)
      assert_match(/github: janedoe/, content)
      assert_match(/twitter: janedoe/, content)
      assert_match(/website: https:\/\/janedoe.example.com/, content)
      assert_match(/mastodon: https:\/\/ruby.social\/@janedoe/, content)
      assert_match(/bluesky: janedoe.bsky.social/, content)
      assert_match(/linkedin: janedoe/, content)
      assert_match(/speakerdeck: janedoe/, content)
    end

    assert_valid_speakers_file
  end

  test "auto-generates the slug from the name when omitted" do
    run_generator ["--name", "Jane Doe", "--github", "janedoe"]

    assert_file speakers_file_path do |content|
      assert_match(/slug: jane-doe/, content)
    end

    assert_valid_speakers_file
  end

  test "updates an existing speaker's socials without removing others or duplicating" do
    run_generator ["--name", "Jane Doe", "--github", "janedoe", "--twitter", "janedoe"]
    run_generator ["--name", "Jane Doe", "--github", "janedoe", "--bluesky", "janedoe.bsky.social"]

    speakers = read_speakers
    janes = speakers.select { |s| s["name"] == "Jane Doe" }
    assert_equal 1, janes.size, "speaker should not be duplicated"

    jane = janes.first
    assert_equal "janedoe", jane["twitter"]
    assert_equal "janedoe.bsky.social", jane["bluesky"]

    assert_valid_speakers_file
  end

  test "reports no changes when nothing is updated" do
    run_generator ["--name", "Jane Doe", "--github", "janedoe"]

    out = run_generator ["--name", "Jane Doe", "--github", "janedoe"]
    assert_match(/already exists/, out)
  end

  test "adds a new speaker with aliases" do
    run_generator [
      "--name", "Jane Doe",
      "--github", "janedoe",
      "--aliases", "J. Doe", "Jane Doe Smith"
    ]

    speakers = read_speakers
    janes = speakers.select { |s| s["name"] == "Jane Doe" }
    assert_equal 1, janes.size

    aliases = janes.first["aliases"]
    assert_equal 2, aliases.size
    assert_includes aliases, {"name" => "J. Doe", "slug" => "j-doe"}
    assert_includes aliases, {"name" => "Jane Doe Smith", "slug" => "jane-doe-smith"}

    assert_valid_speakers_file
  end

  test "aliases are always slugified from the alias name" do
    run_generator [
      "--name", "Jane Doe",
      "--github", "janedoe",
      "--aliases", "J. Doe"
    ]

    speakers = read_speakers
    aliases = speakers.first["aliases"]
    assert_equal 1, aliases.size
    assert_equal "j-doe", aliases.first["slug"]

    assert_valid_speakers_file
  end

  test "adds aliases to an existing speaker without duplicating" do
    run_generator ["--name", "Jane Doe", "--github", "janedoe"]
    run_generator ["--name", "Jane Doe", "--github", "janedoe", "--aliases", "J. Doe"]
    run_generator ["--name", "Jane Doe", "--github", "janedoe", "--aliases", "J. Doe"]
    run_generator ["--name", "Jane Doe", "--github", "janedoe", "--aliases", "Jane Smith"]

    speakers = read_speakers
    janes = speakers.select { |s| s["name"] == "Jane Doe" }
    assert_equal 1, janes.size, "speaker should not be duplicated"

    aliases = janes.first["aliases"]
    assert_equal 2, aliases.size, "existing alias should not be duplicated"
    assert_includes aliases, {"name" => "J. Doe", "slug" => "j-doe"}
    assert_includes aliases, {"name" => "Jane Smith", "slug" => "jane-smith"}

    assert_valid_speakers_file
  end

  test "generates slug from parameterized name when not provided" do
    run_generator ["--name", "Jane Doe", "--github", "janedoe"]

    speakers = read_speakers
    assert_equal "jane-doe", speakers.first["slug"]

    assert_valid_speakers_file
  end

  test "falls back to github handle when parameterized name is blank" do
    run_generator ["--name", "日本語", "--github", "jugyo"]

    speakers = read_speakers
    assert_equal "jugyo", speakers.first["slug"]

    assert_valid_speakers_file
  end
end
