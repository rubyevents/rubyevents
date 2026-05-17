# frozen_string_literal: true

require "test_helper"

class Static::Validators::UniqueSpeakersTest < ActiveSupport::TestCase
  SPEAKERS_FILE = Rails.root.join("data/speakers.yml").to_s

  test "applicable? returns true for speakers.yml" do
    validator = Static::Validators::UniqueSpeakers.new(file_path: SPEAKERS_FILE)
    assert validator.applicable?
  end

  test "applicable? returns false for a non-speakers file" do
    file = Dir.glob(Rails.root.join("data/**/event.yml")).first
    validator = Static::Validators::UniqueSpeakers.new(file_path: file)
    assert_not validator.applicable?
  end

  test "applicable? returns false for a non-existent file" do
    validator = Static::Validators::UniqueSpeakers.new(file_path: "/nonexistent/speakers.yml")
    assert_not validator.applicable?
  end

  test "returns empty errors for the real speakers.yml" do
    validator = Static::Validators::UniqueSpeakers.new(file_path: SPEAKERS_FILE)
    errors = validator.errors
    assert errors.all? { |e| e.is_a?(Static::Validators::Error) }
  end

  test "returns error for same name duplicates" do
    yaml = [
      {"name" => "Alice Smith", "slug" => "alice"},
      {"name" => "Alice Smith", "slug" => "alice-smith-2"}
    ].to_yaml
    with_temp_speakers_yaml(yaml) do |path|
      validator = Static::Validators::UniqueSpeakers.new(file_path: path)
      errors = validator.errors
      assert errors.any? { |e| e.to_h["message"].include?("Same name duplicate") }
      assert errors.any? { |e| e.to_h["message"].include?("Alice Smith") }
      assert errors.any? { |e| e.to_h["message"].include?("2 occurrences") }
    end
  end

  test "returns error for reversed name duplicates" do
    yaml = [
      {"name" => "Alice Smith", "slug" => "alice-smith"},
      {"name" => "Smith Alice", "slug" => "smith-alice"}
    ].to_yaml
    with_temp_speakers_yaml(yaml) do |path|
      validator = Static::Validators::UniqueSpeakers.new(file_path: path)
      errors = validator.errors
      assert errors.any? { |e| e.to_h["message"].include?("Reversed name duplicate") }
      assert errors.any? { |e| e.to_h["message"].include?("Alice Smith") }
      assert errors.any? { |e| e.to_h["message"].include?("Smith Alice") }
      assert errors.any? { |e| e.to_h["message"].include?("↔") }
    end
  end

  test "returns no errors for unique names" do
    yaml = [
      {"name" => "Alice Smith", "slug" => "alice-smith"},
      {"name" => "Bob Jones", "slug" => "bob-jones"}
    ].to_yaml
    with_temp_speakers_yaml(yaml) do |path|
      validator = Static::Validators::UniqueSpeakers.new(file_path: path)
      assert_empty validator.errors
    end
  end

  test "returns error when alias name conflicts with main name" do
    yaml = [
      {"name" => "Alice Smith", "slug" => "alice-smith"},
      {
        "name" => "Bob Jones",
        "slug" => "bob-jones",
        "aliases" => [
          {"name" => "Alice Smith", "slug" => "alice-smith-alias"}
        ]
      }
    ].to_yaml
    with_temp_speakers_yaml(yaml) do |path|
      validator = Static::Validators::UniqueSpeakers.new(file_path: path)
      errors = validator.errors
      assert errors.any? { |e| e.to_h["message"].include?("Alias name") }
      assert errors.any? { |e| e.to_h["message"].include?("alice smith") }
      assert errors.any? { |e| e.to_h["message"].include?("conflicts with main name") }
    end
  end

  test "returns error when alias name is shared across speakers" do
    yaml = [
      {
        "name" => "Alice Smith",
        "slug" => "alice-smith",
        "aliases" => [
          {"name" => "A. Smith", "slug" => "a-smith-1"}
        ]
      },
      {
        "name" => "Bob Jones",
        "slug" => "bob-jones",
        "aliases" => [
          {"name" => "A. Smith", "slug" => "a-smith-2"}
        ]
      }
    ].to_yaml
    with_temp_speakers_yaml(yaml) do |path|
      validator = Static::Validators::UniqueSpeakers.new(file_path: path)
      errors = validator.errors
      assert errors.any? { |e| e.to_h["message"].include?("Alias name") }
      assert errors.any? { |e| e.to_h["message"].include?("a. smith") }
      assert errors.any? { |e| e.to_h["message"].include?("shared across speakers") }
    end
  end

  test "errors are Static::Validators::Error objects" do
    yaml = [
      {"name" => "Alice Smith", "slug" => "alice"},
      {"name" => "Alice Smith", "slug" => "alice-2"}
    ].to_yaml
    with_temp_speakers_yaml(yaml) do |path|
      validator = Static::Validators::UniqueSpeakers.new(file_path: path)
      assert validator.errors.all? { |e| e.is_a?(Static::Validators::Error) }
    end
  end

  test "returns multiple types of errors when present" do
    yaml = [
      {"name" => "Alice Smith", "slug" => "alice-smith"},
      {"name" => "Alice Smith", "slug" => "alice-smith-2"},
      {"name" => "Bob Jones", "slug" => "bob-jones"},
      {"name" => "Jones Bob", "slug" => "jones-bob"},
      {
        "name" => "Carol White",
        "slug" => "carol-white",
        "aliases" => [
          {"name" => "Alice Smith", "slug" => "alice-alias"}
        ]
      }
    ].to_yaml
    with_temp_speakers_yaml(yaml) do |path|
      validator = Static::Validators::UniqueSpeakers.new(file_path: path)
      errors = validator.errors
      assert errors.any? { |e| e.to_h["message"].include?("Same name duplicate") }
      assert errors.any? { |e| e.to_h["message"].include?("Reversed name duplicate") }
      assert errors.any? { |e| e.to_h["message"].include?("Alias name") }
      assert_operator errors.count, :>=, 3
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
