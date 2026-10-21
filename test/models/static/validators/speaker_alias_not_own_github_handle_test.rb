# frozen_string_literal: true

require "test_helper"

class Static::Validators::SpeakerAliasNotOwnGitHubHandleTest < ActiveSupport::TestCase
  self.fixture_table_names = []
  SPEAKERS_FILE = Rails.root.join("data/speakers.yml").to_s

  test "applicable? returns true for speakers.yml" do
    validator = Static::Validators::SpeakerAliasNotOwnGitHubHandle.new(file_path: SPEAKERS_FILE)
    assert validator.applicable?
  end

  test "applicable? returns false for a non-speakers file" do
    file = Dir.glob(Rails.root.join("data/**/event.yml")).first
    validator = Static::Validators::SpeakerAliasNotOwnGitHubHandle.new(file_path: file)
    assert_not validator.applicable?
  end

  test "returns empty errors for the real speakers.yml" do
    validator = Static::Validators::SpeakerAliasNotOwnGitHubHandle.new(file_path: SPEAKERS_FILE)
    assert_empty validator.errors
  end

  test "allows aliases that differ from the GitHub handle" do
    yaml = <<~YAML
      ---
      - name: "Ryosuke Uchida"
        github: "ryosk7"
        slug: "ryosuke-uchida"
        aliases:
          - name: "Ryosuke"
            slug: "ryosuke"
    YAML

    with_temp_speakers_yaml(yaml) do |path|
      assert_empty Static::Validators::SpeakerAliasNotOwnGitHubHandle.new(file_path: path).errors
    end
  end

  test "returns error when an alias is the speaker's own GitHub handle, ignoring case" do
    yaml = <<~YAML
      ---
      - name: "Ryosuke Uchida"
        github: "ryosk7"
        slug: "ryosuke-uchida"
        aliases:
          - name: "RyoSK7"
            slug: "ryosk7"
    YAML

    with_temp_speakers_yaml(yaml) do |path|
      errors = Static::Validators::SpeakerAliasNotOwnGitHubHandle.new(file_path: path).errors
      error = errors.first.to_h

      assert_equal 1, errors.size
      assert_equal %(Alias "RyoSK7" on "Ryosuke Uchida" is redundant, it's already the GitHub handle and GitHub handles act as aliases.), error["message"]
      assert_equal 2, error["line"]
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
