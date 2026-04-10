require "test_helper"
require "json"

class SchemaExportTest < ActiveSupport::TestCase
  SCHEMA_DIR = Rails.root.join("app/schemas")
  JSON_DIR = Rails.root.join("lib/schemas")

  Dir.glob(SCHEMA_DIR.join("*_schema.rb")).each do |schema_file|
    base = File.basename(schema_file, ".rb")
    test "#{base} generates matching JSON schema" do
      schema_class = base.camelize.constantize
      generated = JSON.pretty_generate(schema_class.new.to_json_schema[:schema])
      json_path = JSON_DIR.join("#{base}.json")
      assert File.exist?(json_path), "Missing JSON schema for #{base}. Run `bin/rails schema:export` to generate it."
      expected = File.read(json_path)
      assert_equal expected, generated, "Schema for #{base} is out of date. Run `bin/rails schema:export` to update it."
    end
  end
end
