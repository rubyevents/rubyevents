# frozen_string_literal: true

require "test_helper"

class Static::Validators::UniqueSpeakerFieldsTest < ActiveSupport::TestCase
  SPEAKERS_FILE = Rails.root.join("data/speakers.yml").to_s

  test "applicable? returns true for speakers.yml" do
    validator = Static::Validators::UniqueSpeakerFields.new(file_path: SPEAKERS_FILE)
    assert validator.applicable?
  end

  test "applicable? returns false for a non-speakers file" do
    file = Dir.glob(Rails.root.join("data/**/event.yml")).first
    validator = Static::Validators::UniqueSpeakerFields.new(file_path: file)
    assert_not validator.applicable?
  end

  test "applicable? returns false for a non-existent file" do
    validator = Static::Validators::UniqueSpeakerFields.new(file_path: "/nonexistent/speakers.yml")
    assert_not validator.applicable?
  end

  test "returns empty errors for the real speakers.yml" do
    validator = Static::Validators::UniqueSpeakerFields.new(file_path: SPEAKERS_FILE)
    assert_empty validator.errors
  end

  test "returns error for duplicate slugs" do
    yaml = [
      {"name" => "Alice", "slug" => "alice"},
      {"name" => "Alice II", "slug" => "alice"}
    ].to_yaml
    with_temp_speakers_yaml(yaml) do |path|
      validator = Static::Validators::UniqueSpeakerFields.new(file_path: path)
      assert validator.errors.any? { |e| e.to_h["message"].include?("alice") }
    end
  end

  test "returns error for duplicate github handles" do
    yaml = [
      {"name" => "Alice", "slug" => "alice", "github" => "alicegithub"},
      {"name" => "Alice Clone", "slug" => "alice-clone", "github" => "alicegithub"}
    ].to_yaml
    with_temp_speakers_yaml(yaml) do |path|
      validator = Static::Validators::UniqueSpeakerFields.new(file_path: path)
      assert validator.errors.any? { |e| e.to_h["message"].include?("alicegithub") }
    end
  end

  test "unique slugs and github handles produce no errors" do
    yaml = [
      {"name" => "Alice", "slug" => "alice", "github" => "alice-gh"},
      {"name" => "Bob", "slug" => "bob", "github" => "bob-gh"}
    ].to_yaml
    with_temp_speakers_yaml(yaml) do |path|
      validator = Static::Validators::UniqueSpeakerFields.new(file_path: path)
      assert_empty validator.errors
    end
  end

  test "redirect slugs produce no errors when unique" do
    yaml = [
      {"name" => "Alice", "slug" => "alice", "github" => "alice-gh", "slugs" => ["alice-old"]},
      {"name" => "Bob", "slug" => "bob", "github" => "bob-gh", "slugs" => ["bob-old"]}
    ].to_yaml
    with_temp_speakers_yaml(yaml) do |path|
      assert_empty Static::Validators::UniqueSpeakerFields.new(file_path: path).errors
    end
  end

  test "returns error for a redirect slug that repeats the speaker's slug" do
    yaml = [
      {"name" => "Alice", "slug" => "alice", "github" => "alice-gh", "slugs" => ["alice"]}
    ].to_yaml
    with_temp_speakers_yaml(yaml) do |path|
      errors = Static::Validators::UniqueSpeakerFields.new(file_path: path).errors

      assert_equal ["Slug 'alice' in slugs of 'Alice' is redundant, it's already the slug of the speaker"], errors.map { |e| e.to_h["message"] }
    end
  end

  test "returns error for a redirect slug that is the speaker's GitHub handle" do
    yaml = [
      {"name" => "Yoh Osaki", "slug" => "yoh-osaki", "github" => "youchan", "slugs" => ["YouChan"]}
    ].to_yaml
    with_temp_speakers_yaml(yaml) do |path|
      errors = Static::Validators::UniqueSpeakerFields.new(file_path: path).errors

      assert_equal ["Slug 'YouChan' in slugs of 'Yoh Osaki' is redundant, it's the GitHub handle of the speaker and profile URLs already resolve GitHub handles"], errors.map { |e| e.to_h["message"] }
    end
  end

  test "returns error for a redirect slug used by another speaker" do
    yaml = [
      {"name" => "Alice", "slug" => "alice", "github" => "alice-gh"},
      {"name" => "Bob", "slug" => "bob", "github" => "bob-gh", "slugs" => ["alice"]}
    ].to_yaml
    with_temp_speakers_yaml(yaml) do |path|
      errors = Static::Validators::UniqueSpeakerFields.new(file_path: path).errors

      assert_equal ["Slug 'alice' in slugs of 'Bob' is already used by Alice"], errors.map { |e| e.to_h["message"] }
    end
  end

  test "errors are Static::Validators::Error objects" do
    yaml = [
      {"name" => "Alice", "slug" => "alice"},
      {"name" => "Alice II", "slug" => "alice"}
    ].to_yaml
    with_temp_speakers_yaml(yaml) do |path|
      validator = Static::Validators::UniqueSpeakerFields.new(file_path: path)
      assert validator.errors.all? { |e| e.is_a?(Static::Validators::Error) }
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
