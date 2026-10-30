require "test_helper"
require "json"

class SchemaExportTest < ActiveSupport::TestCase
  ApplicationSchema.schemas.each do |schema_class|
    test "#{schema_class.name.underscore} is in sync with its exported JSON schema" do
      assert schema_class.in_sync?, "The JSON schema for #{schema_class} is missing or out of date. Run `bin/rails schema:export` to update it."
    end
  end
end
