# frozen_string_literal: true

require "test_helper"
require "tempfile"

class Static::Validators::SchemaArrayTest < ActiveSupport::TestCase
  # CFPSchema is simple (link:required, name, open_date, close_date) — good for tests
  VALID_CFP_FILE = Rails.root.join("data/helveticruby/helveticruby-2025/cfp.yml").to_s

  test "returns empty array for a valid file" do
    validator = Static::Validators::SchemaArray.new(file_path: VALID_CFP_FILE, schema: CFPSchema)
    assert_empty validator.validate
  end

  test "returns errors for invalid items" do
    yaml = [{"name" => "CFP without required link"}].to_yaml
    with_temp_yaml(yaml) do |path|
      validator = Static::Validators::SchemaArray.new(file_path: path, schema: CFPSchema)
      errors = validator.validate
      assert errors.any?, "Expected validation errors but got none"
    end
  end

  test "data_pointer is prefixed with item index" do
    yaml = [{"name" => "missing link"}].to_yaml
    with_temp_yaml(yaml) do |path|
      validator = Static::Validators::SchemaArray.new(file_path: path, schema: CFPSchema)
      errors = validator.validate
      assert errors.all? { |e| e["data_pointer"].start_with?("/0") },
        "Expected all data_pointers to start with /0, got: #{errors.map { |e| e["data_pointer"] }}"
    end
  end

  test "data_pointer index increments per item" do
    yaml = [{"name" => "first"}, {"name" => "second"}].to_yaml
    with_temp_yaml(yaml) do |path|
      validator = Static::Validators::SchemaArray.new(file_path: path, schema: CFPSchema)
      errors = validator.validate
      pointers = errors.map { |e| e["data_pointer"] }
      assert pointers.any? { |p| p.start_with?("/0") }, "Expected errors for item 0"
      assert pointers.any? { |p| p.start_with?("/1") }, "Expected errors for item 1"
    end
  end

  test "item_label uses name when present" do
    yaml = [{"name" => "My CFP"}].to_yaml
    with_temp_yaml(yaml) do |path|
      validator = Static::Validators::SchemaArray.new(file_path: path, schema: CFPSchema)
      errors = validator.validate
      assert errors.all? { |e| e["item_label"] == "My CFP" },
        "Expected item_label to be 'My CFP'"
    end
  end

  test "item_label uses title when name is absent" do
    yaml = [{"title" => "My Talk", "date" => "2025-01-01", "video_provider" => "youtube", "video_id" => "abc123", "id" => "abc"}].to_yaml
    with_temp_yaml(yaml) do |path|
      validator = Static::Validators::SchemaArray.new(file_path: path, schema: VideoSchema)
      errors = validator.validate
      assert errors.all? { |e| e["item_label"] == "My Talk" },
        "Expected item_label to be 'My Talk', got: #{errors.map { |e| e["item_label"] }.inspect}"
    end
  end

  test "item_label falls back to index N when no identifying fields" do
    yaml = [{}].to_yaml
    with_temp_yaml(yaml) do |path|
      validator = Static::Validators::SchemaArray.new(file_path: path, schema: CFPSchema)
      errors = validator.validate
      assert errors.all? { |e| e["item_label"] == "index 0" },
        "Expected item_label to be 'index 0', got: #{errors.map { |e| e["item_label"] }.inspect}"
    end
  end

  test "accepts schema instance as well as schema class" do
    yaml = [{"name" => "missing link"}].to_yaml
    with_temp_yaml(yaml) do |path|
      validator = Static::Validators::SchemaArray.new(file_path: path, schema: CFPSchema.new)
      errors = validator.validate
      assert errors.any?, "Expected validation errors but got none"
    end
  end

  private

  def with_temp_yaml(yaml_content)
    Tempfile.create(["schema_array_test", ".yml"]) do |f|
      f.write(yaml_content)
      f.flush
      yield f.path
    end
  end
end
