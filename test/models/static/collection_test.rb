require "test_helper"

class Yerba::Record::CollectionTest < ActiveSupport::TestCase
  setup do
    @tmp_file = Tempfile.new(["videos", ".yml"])
    @tmp_file.write(<<~YAML)
      ---
      - id: "talk-1"
        title: "Ruby 4.0"
        language: "English"
        speakers:
          - Alice
      - id: "talk-2"
        title: "Rails 8"
        language: "English"
        speakers:
          - Bob
      - id: "talk-3"
        title: "Hanami 2"
        language: "Japanese"
        speakers:
          - Charlie
    YAML
    @tmp_file.flush
    @document = Yerba::Record::Document.new(@tmp_file.path)
    @collection = Yerba::Record::Collection.new(document: @document)
  end

  teardown do
    @tmp_file.close
    @tmp_file.unlink
  end

  test "count returns number of entries" do
    assert_equal 3, @collection.count
  end

  test "first returns first entry" do
    assert_equal "talk-1", @collection.first["id"]
  end

  test "last returns last entry" do
    assert_equal "talk-3", @collection.last["id"]
  end

  test "[] accesses by index" do
    assert_equal "talk-2", @collection[1]["id"]
  end

  test "[] supports negative indices" do
    assert_equal "talk-3", @collection[-1]["id"]
  end

  test "each yields all entries" do
    ids = @collection.map { |entry| entry["id"] }

    assert_equal ["talk-1", "talk-2", "talk-3"], ids
  end

  test "find_by returns matching entry" do
    entry = @collection.find_by(id: "talk-2")

    assert_equal "Rails 8", entry.title
  end

  test "find_by returns nil when no match" do
    entry = @collection.find_by(id: "nonexistent")

    assert_nil entry
  end

  test "where returns all matching entries" do
    entries = @collection.where(language: "English")

    assert_equal 2, entries.size
    assert_equal ["talk-1", "talk-2"], entries.map { |entry| entry["id"] }
  end

  test "create appends entry and saves" do
    @collection.create(id: "talk-4", title: "New Talk", language: "English")

    reloaded = Yerba::Record::Document.new(@tmp_file.path)
    collection = Yerba::Record::Collection.new(document: reloaded)

    assert_equal 4, collection.count
    assert_equal "talk-4", collection.last["id"]
  end

  test "destroy removes entry and saves" do
    @collection.first.destroy

    reloaded = Yerba::Record::Document.new(@tmp_file.path)
    collection = Yerba::Record::Collection.new(document: reloaded)

    assert_equal 2, collection.count
    assert_equal "talk-2", collection.first["id"]
  end

  test "pluck extracts field values" do
    titles = @collection.pluck("title")

    assert_equal ["Ruby 4.0", "Rails 8", "Hanami 2"], titles
  end

  test "empty? returns false for non-empty collection" do
    assert_not @collection.empty?
  end

  test "empty? returns true for empty collection" do
    tmp = Tempfile.new(["empty", ".yml"])
    tmp.write("---\n[]\n")
    tmp.flush

    document = Yerba::Record::Document.new(tmp.path)
    collection = Yerba::Record::Collection.new(document: document)

    assert collection.empty?
  ensure
    tmp&.close
    tmp&.unlink
  end

  test "works with custom entry class" do
    collection = Yerba::Record::Collection.new(document: @document, entry_class: Static::Video)
    video = collection.first

    assert_instance_of Static::Video, video
    assert_equal ["Alice"], video.speakers.names
  end

  test "save! persists all pending changes" do
    @collection.first["title"] = "Modified"
    @collection.last["title"] = "Also Modified"
    @collection.save!

    reloaded = Yerba::Record::Document.new(@tmp_file.path)
    assert_equal "Modified", reloaded.root[0]["title"]
    assert_equal "Also Modified", reloaded.root[2]["title"]
  end

  test "changed? reflects pending mutations" do
    assert_not @collection.changed?

    @collection.first["title"] = "Changed"

    assert @collection.changed?
  end

  test "where returns empty array when no matches" do
    result = @collection.where(language: "Klingon")

    assert_equal [], result
  end

  test "find_by with multiple criteria" do
    entry = @collection.find_by(id: "talk-2", language: "English")

    assert_not_nil entry
    assert_equal "Rails 8", entry["title"]
  end

  test "enumerable methods work" do
    titles = @collection.map { |entry| entry["title"] }
    assert_equal 3, titles.size

    english = @collection.select { |entry| entry["language"] == "English" }
    assert_equal 2, english.size

    found = @collection.any? { |entry| entry["id"] == "talk-3" }
    assert found
  end

  test "create then find_by returns the new entry" do
    @collection.create(id: "talk-new", title: "Brand New", language: "English")

    reloaded_document = Yerba::Record::Document.new(@tmp_file.path)
    reloaded = Yerba::Record::Collection.new(document: reloaded_document)
    entry = reloaded.find_by(id: "talk-new")

    assert_not_nil entry
    assert_equal "Brand New", entry["title"]
  end

  test "mutate entry field and save via collection" do
    @collection.find_by(id: "talk-1")["title"] = "Ruby 5.0"
    @collection.save!

    reloaded = Yerba::Record::Document.new(@tmp_file.path)
    collection = Yerba::Record::Collection.new(document: reloaded)

    assert_equal "Ruby 5.0", collection.find_by(id: "talk-1")["title"]
  end

  test "speakers can be appended via <<" do
    collection = Yerba::Record::Collection.new(document: @document, entry_class: Static::Video)
    video = collection.first

    video.speakers << "NewSpeaker"
    collection.save!

    reloaded = Yerba::Record::Document.new(@tmp_file.path)
    reloaded_collection = Yerba::Record::Collection.new(document: reloaded, entry_class: Static::Video)

    assert_includes reloaded_collection.first.speakers.names, "NewSpeaker"
  end
end
