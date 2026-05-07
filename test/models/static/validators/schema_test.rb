# frozen_string_literal: true

require "test_helper"

class Static::Validators::SchemaTest < ActiveSupport::TestCase
  test "applicable? returns true for a valid event.yml" do
    file = Rails.root.join("data/helveticruby/helveticruby-2025/event.yml")
    validator = Static::Validators::Schema.new(file_path: file)
    assert validator.applicable?
  end

  test "applicable? returns true for series.yml" do
    file = Rails.root.join("data/blue-ridge-ruby/series.yml")
    validator = Static::Validators::Schema.new(file_path: file)
    assert validator.applicable?
  end

  test "applicable? returns false for a non-existent file" do
    validator = Static::Validators::Schema.new(file_path: "/nonexistent/event.yml")
    assert_not validator.applicable?
  end

  test "applicable? returns false for an array-based file" do
    file = Rails.root.join("data/blue-ridge-ruby/videos.yml")
    validator = Static::Validators::Schema.new(file_path: file)
    assert_not validator.applicable?
  end

  test "returns empty array for a valid file" do
    file = Rails.root.join("data/helveticruby/helveticruby-2025/event.yml")
    validator = Static::Validators::Schema.new(file_path: file)
    assert_empty validator.errors
  end

  test "returns errors for an invalid file" do
    yaml = {"name" => "Bad Event"}.to_yaml
    with_temp_event_yaml(yaml) do |path|
      validator = Static::Validators::Schema.new(file_path: path)
      assert_match(/line 2: object property at `\/name` is a disallowed additional property at \/name/, validator.errors.first.as_error)
    end
  end

  test "errors are Static::Validators::Error objects" do
    yaml = {"name" => "Bad Event"}.to_yaml
    with_temp_event_yaml(yaml) do |path|
      validator = Static::Validators::Schema.new(file_path: path)
      assert validator.errors.all? { |e| e.is_a?(Static::Validators::Error) }
    end
  end

  test "returns empty array when file does not exist" do
    validator = Static::Validators::Schema.new(file_path: "/nonexistent/path/event.yml")
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
