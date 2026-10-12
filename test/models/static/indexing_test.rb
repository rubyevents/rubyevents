require "test_helper"

class Yerba::Record::IndexingTest < ActiveSupport::TestCase
  setup do
    @tmp_file = Tempfile.new(["records", ".yml"])
    @tmp_file.write(<<~YAML)
      ---
      - name: "Alice"
        handle: "alice"
        aliases:
          - name: "Bob"
        tags:
          - "ruby"

      - name: "Bob"

      - name: "Carol"
        handle: "carol"
        aliases:
          - name: "Caz"
        tags:
          - "rails"
          - "ruby"
    YAML
    @tmp_file.flush

    @record_class = Class.new(Yerba::Record::Base)
    @record_class.path = @tmp_file.path
    @record_class.add_index :name, include: "aliases[].name"
    @record_class.add_index :handle
    @record_class.add_index :tag, include: "tags[]"
  end

  teardown do
    @tmp_file.close
    @tmp_file.unlink
  end

  test "find_by on an indexed field returns the record at the right position" do
    assert_equal "Carol", @record_class.find_by(name: "Carol").name
    assert_equal "Carol", @record_class.find_by(handle: "carol").name
  end

  test "records without the indexed field don't shift the positions of later records" do
    assert_equal "Carol", @record_class.find_by(handle: "carol").name
    assert_equal({"alice" => 0, "carol" => 2}, @record_class.index_on(:handle).positions)
  end

  test "find_by resolves values at the include selector" do
    assert_equal "Carol", @record_class.find_by(name: "Caz").name
  end

  test "a record's own value wins over another record's included value" do
    assert_equal "Bob", @record_class.find_by(name: "Bob").name
  end

  test "include supports lists of scalars and keeps the first record listing a value" do
    assert_equal "Carol", @record_class.find_by(tag: "rails").name
    assert_equal "Alice", @record_class.find_by(tag: "ruby").name
  end

  test "positions only hold the field's own values" do
    assert_equal({"Alice" => 0, "Bob" => 1, "Carol" => 2}, @record_class.index_on(:name).positions)
    assert_equal({"Bob" => 0, "Caz" => 2}, @record_class.index_on(:name).included_positions)
  end

  test "find_by returns nil for unknown and blank values" do
    assert_nil @record_class.find_by(name: "Dave")
    assert_nil @record_class.find_by(handle: "")
  end
end
