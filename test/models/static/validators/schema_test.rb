# frozen_string_literal: true

require "test_helper"
require "tempfile"

class Static::Validators::SchemaTest < ActiveSupport::TestCase
  VALID_EVENT_FILE = Rails.root.join("data/helveticruby/helveticruby-2025/event.yml").to_s

  test "applicable? returns true for a valid event.yml" do
    validator = Static::Validators::Schema.new(file_path: VALID_EVENT_FILE, schema: EventSchema)
    assert validator.applicable?
  end

  test "applicable? returns true for series.yml" do
    file = Dir.glob(Rails.root.join("data/*/series.yml")).first
    validator = Static::Validators::Schema.new(file_path: file, schema: SeriesSchema)
    assert validator.applicable?
  end

  test "applicable? returns false for a non-existent file" do
    validator = Static::Validators::Schema.new(file_path: "/nonexistent/event.yml", schema: EventSchema)
    assert_not validator.applicable?
  end

  test "applicable? returns false for an array-based file" do
    file = Dir.glob(Rails.root.join("data/**/videos.yml")).first
    validator = Static::Validators::Schema.new(file_path: file, schema: VideoSchema)
    assert_not validator.applicable?
  end

  test "returns empty array for a valid file" do
    validator = Static::Validators::Schema.new(file_path: VALID_EVENT_FILE, schema: EventSchema)
    assert_empty validator.errors
  end

  test "returns errors for an invalid file" do
    yaml = {"name" => "Bad Event"}.to_yaml
    with_temp_event_yaml(yaml) do |path|
      validator = Static::Validators::Schema.new(file_path: path, schema: EventSchema)
      assert validator.errors.any?, "Expected validation errors but got none"
    end
  end

  test "errors are Static::Validators::Error objects" do
    yaml = {"name" => "Bad Event"}.to_yaml
    with_temp_event_yaml(yaml) do |path|
      validator = Static::Validators::Schema.new(file_path: path, schema: EventSchema)
      assert validator.errors.all? { |e| e.is_a?(Static::Validators::Error) }
    end
  end

  test "returns empty array when file does not exist" do
    validator = Static::Validators::Schema.new(file_path: "/nonexistent/path/event.yml", schema: EventSchema)
    assert_empty validator.errors
  end

  test "accepts schema instance as well as schema class" do
    validator = Static::Validators::Schema.new(file_path: VALID_EVENT_FILE, schema: EventSchema.new)
    assert_empty validator.errors
  end

  private

  def with_temp_event_yaml(yaml_content)
    dir = Dir.mktmpdir
    path = File.join(dir, "data", "testconf", "2025", "event.yml")
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, yaml_content)
    yield path
  ensure
    FileUtils.rm_rf(dir)
  end
end
