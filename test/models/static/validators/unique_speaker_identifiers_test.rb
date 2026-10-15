# frozen_string_literal: true

require "test_helper"

class Static::Validators::UniqueSpeakerIdentifiersTest < ActiveSupport::TestCase
  self.fixture_table_names = []
  SPEAKERS_FILE = Rails.root.join("data/speakers.yml").to_s

  test "applicable? returns true for speakers.yml" do
    validator = Static::Validators::UniqueSpeakerIdentifiers.new(file_path: SPEAKERS_FILE)
    assert validator.applicable?
  end

  test "applicable? returns false for a non-speakers file" do
    file = Dir.glob(Rails.root.join("data/**/event.yml")).first
    validator = Static::Validators::UniqueSpeakerIdentifiers.new(file_path: file)
    assert_not validator.applicable?
  end

  test "returns empty errors for the real speakers.yml" do
    validator = Static::Validators::UniqueSpeakerIdentifiers.new(file_path: SPEAKERS_FILE)
    assert_empty validator.errors
  end

  test "allows a speaker named after their own GitHub handle" do
    yaml = <<~YAML
      ---
      - name: "buty4649"
        github: "buty4649"
        slug: "buty4649"
    YAML

    with_temp_speakers_yaml(yaml) do |path|
      assert_empty Static::Validators::UniqueSpeakerIdentifiers.new(file_path: path).errors
    end
  end

  test "returns error when a speaker's names only differ in case" do
    yaml = <<~YAML
      ---
      - name: "Hiroshi SHIBATA"
        github: "hsbt"
        slug: "hiroshi-shibata"
        aliases:
          - "Hiroshi Shibata"
    YAML

    with_temp_speakers_yaml(yaml) do |path|
      errors = Static::Validators::UniqueSpeakerIdentifiers.new(file_path: path).errors

      assert_equal 1, errors.size
      assert_equal %(Speaker names only differ in case or whitespace on "Hiroshi SHIBATA": name "Hiroshi SHIBATA", alias "Hiroshi Shibata". Name lookups ignore case and surrounding whitespace, so keep only one of them.), errors.first.to_h["message"]
    end
  end

  test "returns error when a speaker's aliases only differ in surrounding whitespace" do
    yaml = <<~YAML
      ---
      - name: "Vishwajeetsingh Desurkar"
        github: ""
        slug: "vishwajeetsingh-desurkar"
        aliases:
          - "Vishwajeetsingh Desurkar "
    YAML

    with_temp_speakers_yaml(yaml) do |path|
      assert_equal 1, Static::Validators::UniqueSpeakerIdentifiers.new(file_path: path).errors.size
    end
  end

  test "returns error when a name is another speaker's GitHub handle" do
    yaml = <<~YAML
      ---
      - name: "Keith Gaddis"
        github: "karmajunkie"
        slug: "keith-gaddis"
      - name: "karmajunkie"
        github: ""
        slug: "karmajunkie"
    YAML

    with_temp_speakers_yaml(yaml) do |path|
      errors = Static::Validators::UniqueSpeakerIdentifiers.new(file_path: path).errors
      error = errors.first.to_h

      assert_equal 1, errors.size
      assert_equal %(Speaker identifier used by more than one speaker: GitHub handle "karmajunkie" of "Keith Gaddis", name "karmajunkie" of "karmajunkie". Names, aliases, and GitHub handles must each identify a single speaker.), error["message"]
      assert_equal 5, error["line"]
    end
  end

  test "returns error when an alias is another speaker's GitHub handle, ignoring case" do
    yaml = <<~YAML
      ---
      - name: "Pablo Astigarraga"
        github: "pote"
        slug: "pablo-astigarraga"
      - name: "Someone Else"
        github: ""
        slug: "someone-else"
        aliases:
          - "Pote"
    YAML

    with_temp_speakers_yaml(yaml) do |path|
      errors = Static::Validators::UniqueSpeakerIdentifiers.new(file_path: path).errors

      assert_equal 1, errors.size
      assert_includes errors.first.to_h["message"], %(alias "Pote" of "Someone Else")
    end
  end

  test "returns error when an alias is another speaker's name" do
    yaml = <<~YAML
      ---
      - name: "Jane Doe"
        github: ""
        slug: "jane-doe"
      - name: "Janet Doe"
        github: ""
        slug: "janet-doe"
        aliases:
          - "jane doe"
    YAML

    with_temp_speakers_yaml(yaml) do |path|
      errors = Static::Validators::UniqueSpeakerIdentifiers.new(file_path: path).errors

      assert_equal 1, errors.size
      assert_includes errors.first.to_h["message"], %(name "Jane Doe" of "Jane Doe", alias "jane doe" of "Janet Doe")
    end
  end

  test "returns error when an additional GitHub handle belongs to another speaker" do
    yaml = <<~YAML
      ---
      - name: "Yatish Mehta"
        github: "yatish27"
        github_handles:
          - "yatish-asana"
        slug: "yatish-mehta"
      - name: "Someone Else"
        github: "Yatish-Asana"
        slug: "someone-else"
    YAML

    with_temp_speakers_yaml(yaml) do |path|
      errors = Static::Validators::UniqueSpeakerIdentifiers.new(file_path: path).errors

      assert_equal 1, errors.size
      assert_includes errors.first.to_h["message"], %(GitHub handle "yatish-asana" of "Yatish Mehta")
    end
  end

  private

  def with_temp_speakers_yaml(yaml_content)
    dir = Dir.mktmpdir
    path = File.join(dir, "data", "speakers.yml")
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, yaml_content)
    yield path
  ensure
    FileUtils.rm_rf(dir)
  end
end
