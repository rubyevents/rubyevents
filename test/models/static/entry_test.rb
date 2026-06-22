require "test_helper"

class Yerba::Record::EntryTest < ActiveSupport::TestCase
  setup do
    @tmp_file = Tempfile.new(["test", ".yml"])
    @tmp_file.write(<<~YAML)
      ---
      - name: "Alice"
        slug: "alice"
        github: "alice123"
      - name: "Bob"
        slug: "bob"
    YAML
    @tmp_file.flush
    @document = Yerba::Record::Document.new(@tmp_file.path)
  end

  teardown do
    @tmp_file.close
    @tmp_file.unlink
  end

  test "reads fields via method_missing" do
    entry = Yerba::Record::Entry.new(document: @document, index: 0)

    assert_equal "Alice", entry.name
    assert_equal "alice", entry.slug
  end

  test "reads fields via bracket access" do
    entry = Yerba::Record::Entry.new(document: @document, index: 0)

    assert_equal "Alice", entry["name"]
  end

  test "writes fields via setter" do
    entry = Yerba::Record::Entry.new(document: @document, index: 0)
    entry.name = "Updated"

    assert_equal "Updated", entry.name
  end

  test "writes fields via bracket assignment" do
    entry = Yerba::Record::Entry.new(document: @document, index: 0)
    entry["name"] = "Updated"

    assert_equal "Updated", entry["name"]
  end

  test "save! persists changes to file" do
    entry = Yerba::Record::Entry.new(document: @document, index: 0)
    entry.name = "Updated"
    entry.save!

    reloaded = Yerba.parse_file(@tmp_file.path)
    assert_equal "Updated", reloaded.value_at("[0].name")
  end

  test "destroy removes entry from array" do
    entry = Yerba::Record::Entry.new(document: @document, index: 0)
    entry.destroy

    reloaded = Yerba.parse_file(@tmp_file.path)
    assert_equal 1, reloaded.root.length
    assert_equal "Bob", reloaded.value_at("[0].name")
  end

  test "to_h returns hash representation" do
    entry = Yerba::Record::Entry.new(document: @document, index: 0)

    hash = entry.to_h
    assert_equal "Alice", hash["name"]
    assert_equal "alice", hash["slug"]
  end

  test "respond_to_missing? works for existing fields" do
    entry = Yerba::Record::Entry.new(document: @document, index: 0)

    assert entry.respond_to?(:name)
    assert entry.respond_to?(:slug)
    assert entry.respond_to?(:name=)
    assert_not entry.respond_to?(:nonexistent)
  end

  test "raises NoMethodError for missing fields" do
    entry = Yerba::Record::Entry.new(document: @document, index: 0)

    assert_raises(NoMethodError) { entry.nonexistent }
  end

  test "works as single-object entry without index" do
    tmp = Tempfile.new(["single", ".yml"])
    tmp.write(<<~YAML)
      ---
      name: "Venue"
      city: "Portland"
    YAML
    tmp.flush

    document = Yerba::Record::Document.new(tmp.path)
    entry = Yerba::Record::Entry.new(document: document)

    assert_equal "Venue", entry.name
    assert_equal "Portland", entry.city

    entry.city = "Seattle"
    entry.save!

    reloaded = Yerba.parse_file(tmp.path)
    assert_equal "Seattle", reloaded.value_at("city")
  ensure
    tmp&.close
    tmp&.unlink
  end
end
