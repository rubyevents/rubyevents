# frozen_string_literal: true

require "test_helper"

class Static::Validators::SchemaTest < ActiveSupport::TestCase
  test "applicable? returns true for a mapping-based file like event.yml" do
    file = Rails.root.join("data/helveticruby/helveticruby-2025/event.yml")

    assert Static::Validators::Schema.new(file_path: file).applicable?
  end

  test "applicable? returns true for an array-based file like videos.yml" do
    file = Rails.root.join("data/helveticruby/helveticruby-2025/videos.yml")

    assert Static::Validators::Schema.new(file_path: file).applicable?
  end

  test "applicable? returns false for a non-existent file" do
    assert_not Static::Validators::Schema.new(file_path: "/nonexistent/event.yml").applicable?
  end

  test "applicable? returns false for a file without a schema" do
    with_temp_yaml("something.yml", "---\nname: 5\n") do |path|
      assert_not Static::Validators::Schema.new(file_path: path).applicable?
    end
  end

  test "returns empty array for a valid mapping-based file" do
    file = Rails.root.join("data/helveticruby/helveticruby-2025/event.yml")

    assert_empty Static::Validators::Schema.new(file_path: file).errors
  end

  test "returns empty array for a valid array-based file" do
    file = Rails.root.join("data/helveticruby/helveticruby-2025/cfp.yml")

    assert_empty Static::Validators::Schema.new(file_path: file).errors
  end

  test "returns errors for an invalid mapping-based file" do
    with_temp_yaml("event.yml", %(---\nname: "Bad Event"\n)) do |path|
      errors = Static::Validators::Schema.new(file_path: path).errors

      assert_match(/"id" is a required property/, errors.first.as_error)
    end
  end

  test "returns errors with the item label for an invalid array-based file" do
    with_temp_yaml("cfp.yml", %(---\n- name: "CFP without required link"\n)) do |path|
      errors = Static::Validators::Schema.new(file_path: path).errors

      assert_match(/"link" is a required property/, errors.first.as_error)
      assert_match(/CFP without required link/, errors.first.as_error)
    end
  end

  test "a passed selector overrides the schema's data file selector" do
    with_temp_yaml("event.yml", %(---\n- name: "Event in an unexpected array"\n)) do |path|
      errors = Static::Validators::Schema.new(file_path: path, selector: "[]").errors

      assert_match(/"id" is a required property/, errors.first.as_error)
    end
  end

  test "errors are Static::Validators::Error objects" do
    with_temp_yaml("event.yml", %(---\nname: "Bad Event"\n)) do |path|
      errors = Static::Validators::Schema.new(file_path: path).errors

      assert errors.all? { |error| error.is_a?(Static::Validators::Error) }
    end
  end

  test "returns empty array when file does not exist" do
    assert_empty Static::Validators::Schema.new(file_path: "/nonexistent/path/event.yml").errors
  end

  private

  def with_temp_yaml(filename, content)
    dir = Dir.mktmpdir
    path = File.join(dir, "data", "testconf", "testconf-2025", filename)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
    yield path
  ensure
    FileUtils.rm_rf(dir)
  end
end
