require "test_helper"

class Yerba::Record::DocumentTest < ActiveSupport::TestCase
  setup do
    @tmp_file = Tempfile.new(["test", ".yml"])
    @tmp_file.write(<<~YAML)
      ---
      - name: "Alice"
        slug: "alice"
      - name: "Bob"
        slug: "bob"
    YAML
    @tmp_file.flush
  end

  teardown do
    @tmp_file.close
    @tmp_file.unlink
  end

  test "loads YAML file lazily" do
    document = Yerba::Record::Document.new(@tmp_file.path)

    assert_equal 2, document.root.length
  end

  test "exist? returns true for existing file" do
    document = Yerba::Record::Document.new(@tmp_file.path)

    assert document.exist?
  end

  test "exist? returns false for missing file" do
    document = Yerba::Record::Document.new("/nonexistent/file.yml")

    assert_not document.exist?
  end

  test "save! writes changes to file" do
    document = Yerba::Record::Document.new(@tmp_file.path)
    document.root[0]["name"] = "Updated"
    document.save!

    reloaded = Yerba.parse_file(@tmp_file.path)
    assert_equal "Updated", reloaded.value_at("[0].name")
  end

  test "raises StaleFileError when file modified externally" do
    document = Yerba::Record::Document.new(@tmp_file.path)
    document.root # trigger lazy load

    sleep 0.1
    File.write(@tmp_file.path, File.read(@tmp_file.path))

    assert_raises(Yerba::StaleFileError) do
      document.save!
    end
  end

  test "allows consecutive saves" do
    document = Yerba::Record::Document.new(@tmp_file.path)
    document.root[0]["name"] = "First"
    document.save!

    document.root[1]["name"] = "Second"
    document.save!

    reloaded = Yerba.parse_file(@tmp_file.path)
    assert_equal "First", reloaded.value_at("[0].name")
    assert_equal "Second", reloaded.value_at("[1].name")
  end

  test ".create creates a new document from content" do
    path = "#{Dir.tmpdir}/static_doc_test_#{SecureRandom.hex(4)}.yml"

    document = Yerba::Record::Document.create(path, [{name: "Test", slug: "test"}])

    assert File.exist?(path)
    assert_equal 1, document.root.length
    assert_equal "Test", document.root[0]["name"]
  ensure
    File.delete(path) if File.exist?(path)
  end
end
