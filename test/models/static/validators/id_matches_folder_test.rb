# frozen_string_literal: true

require "test_helper"

class Static::Validators::IdMatchesFolderTest < ActiveSupport::TestCase
  VALID_EVENT_FILE = Rails.root.join("data/helveticruby/helveticruby-2025/event.yml").to_s
  VALID_SERIES_FILE = Rails.root.join("data/helveticruby/series.yml").to_s

  test "applicable? returns true for an event.yml file" do
    validator = Static::Validators::IdMatchesFolder.new(file_path: VALID_EVENT_FILE)
    assert validator.applicable?
  end

  test "applicable? returns true for a series.yml file" do
    validator = Static::Validators::IdMatchesFolder.new(file_path: VALID_SERIES_FILE)
    assert validator.applicable?
  end

  test "applicable? returns false for a videos.yml file" do
    file = Dir.glob(Rails.root.join("data/**/videos.yml")).first
    validator = Static::Validators::IdMatchesFolder.new(file_path: file)
    assert_not validator.applicable?
  end

  test "applicable? returns false for a non-existent file" do
    validator = Static::Validators::IdMatchesFolder.new(file_path: "/nonexistent/event.yml")
    assert_not validator.applicable?
  end

  test "returns empty errors when event id matches the folder name" do
    validator = Static::Validators::IdMatchesFolder.new(file_path: VALID_EVENT_FILE)
    assert_empty validator.errors
  end

  test "returns empty errors when series id matches the folder name" do
    validator = Static::Validators::IdMatchesFolder.new(file_path: VALID_SERIES_FILE)
    assert_empty validator.errors
  end

  test "returns error when event id does not match the folder name" do
    yaml = {"id" => "some-other-event", "title" => "RubyConf", "kind" => "conference"}.to_yaml
    with_temp_yaml("testconf-2025/event.yml", yaml) do |path|
      validator = Static::Validators::IdMatchesFolder.new(file_path: path)
      assert_equal 1, validator.errors.count
      assert_includes validator.errors.first.to_h["message"], 'id "some-other-event" does not match the folder name "testconf-2025"'
    end
  end

  test "returns error when series id does not match the folder name" do
    yaml = {"id" => "wrong-series", "name" => "TestConf"}.to_yaml
    with_temp_yaml("testconf/series.yml", yaml) do |path|
      validator = Static::Validators::IdMatchesFolder.new(file_path: path)
      assert_equal 1, validator.errors.count
      assert_includes validator.errors.first.to_h["message"], 'id "wrong-series" does not match the folder name "testconf"'
    end
  end

  test "returns error when id is missing" do
    yaml = {"title" => "RubyConf", "kind" => "conference"}.to_yaml
    with_temp_yaml("testconf-2025/event.yml", yaml) do |path|
      validator = Static::Validators::IdMatchesFolder.new(file_path: path)
      assert_equal 1, validator.errors.count
      assert_includes validator.errors.first.to_h["message"], "id is required"
    end
  end

  test "errors are Static::Validators::Error objects" do
    yaml = {"id" => "mismatch", "title" => "RubyConf", "kind" => "conference"}.to_yaml
    with_temp_yaml("testconf-2025/event.yml", yaml) do |path|
      validator = Static::Validators::IdMatchesFolder.new(file_path: path)
      assert validator.errors.all? { |e| e.is_a?(Static::Validators::Error) }
    end
  end

  private

  def with_temp_yaml(relative_path, yaml_content)
    dir = Dir.mktmpdir
    path = File.join(dir, "data", relative_path)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, yaml_content)
    yield path
  ensure
    FileUtils.rm_rf(dir)
  end
end
