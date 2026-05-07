# frozen_string_literal: true

require "test_helper"

class Static::Validators::SchemaArrayTest < ActiveSupport::TestCase
  # CFPSchema is simple (link:required, name, open_date, close_date) — good for tests
  VALID_CFP_FILE = Rails.root.join("data/helveticruby/helveticruby-2025/cfp.yml").to_s

  test "returns empty array for a valid file" do
    validator = Static::Validators::SchemaArray.new(file_path: VALID_CFP_FILE, schema: CFPSchema)
    assert_empty validator.validate
  end

  test "returns errors for invalid items" do
    with_temp_cfp_yaml([{"name" => "CFP without required link"}].to_yaml) do |path|
      validator = Static::Validators::SchemaArray.new(file_path: path, schema: CFPSchema)
      assert validator.validate.any?, "Expected validation errors but got none"
    end
  end

  test "errors are Static::Validators::Error objects" do
    with_temp_cfp_yaml([{"name" => "missing link"}].to_yaml) do |path|
      validator = Static::Validators::SchemaArray.new(file_path: path, schema: CFPSchema)
      assert validator.validate.all? { |e| e.is_a?(Static::Validators::Error) }
    end
  end

  test "returns errors for multiple invalid items" do
    with_temp_cfp_yaml([{"name" => "first"}, {"name" => "second"}].to_yaml) do |path|
      validator = Static::Validators::SchemaArray.new(file_path: path, schema: CFPSchema)
      assert validator.validate.count >= 2, "Expected errors for both items"
    end
  end

  test "accepts schema instance as well as schema class" do
    with_temp_cfp_yaml([{"name" => "missing link"}].to_yaml) do |path|
      validator = Static::Validators::SchemaArray.new(file_path: path, schema: CFPSchema.new)
      assert validator.validate.any?, "Expected validation errors but got none"
    end
  end

  test "applicable? returns true for cfp.yml" do
    validator = Static::Validators::SchemaArray.new(file_path: VALID_CFP_FILE, schema: CFPSchema)
    assert validator.applicable?
  end

  test "applicable? returns false for a non-array file" do
    file = Dir.glob(Rails.root.join("data/**/event.yml")).first
    validator = Static::Validators::SchemaArray.new(file_path: file, schema: EventSchema)
    assert_not validator.applicable?
  end

  test "applicable? returns false for a non-existent file" do
    validator = Static::Validators::SchemaArray.new(file_path: "/nonexistent/cfp.yml", schema: CFPSchema)
    assert_not validator.applicable?
  end

  private

  def with_temp_cfp_yaml(yaml_content)
    dir = Dir.mktmpdir
    path = File.join(dir, "data", "testconf", "testconf-2025", "cfp.yml")
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, yaml_content)
    yield path
  ensure
    FileUtils.rm_rf(dir)
  end
end
