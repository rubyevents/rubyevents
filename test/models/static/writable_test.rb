require "test_helper"

class Static::WritableTest < ActiveSupport::TestCase
  test "event is directly readable and writable" do
    event = Static::Event.find_by_slug("rubyconf-2026")

    assert_instance_of Static::Event, event
    assert_equal "RubyConf 2026", event.title
    assert_equal "conference", event.kind
    assert event["start_date"].present?
  end

  test "event fields can be modified" do
    event = Static::Event.find_by_slug("rubyconf-2026")

    original_title = event.title
    event.title = "Modified Title"
    assert_equal "Modified Title", event.title
    assert event.changed?

    # Reset without saving
    event.title = original_title
  end

  test "update modifies fields and saves" do
    tmp_dir = Dir.mktmpdir
    event_dir = File.join(tmp_dir, "test-series", "test-event")
    FileUtils.mkdir_p(event_dir)

    File.write(File.join(event_dir, "event.yml"), <<~YAML)
      ---
      title: "Test Event"
      kind: "conference"
      location: "Portland, USA"
    YAML

    document = Yerba::Record::Document.new(File.join(event_dir, "event.yml"))
    entry = Yerba::Record::Entry.new(document: document)

    entry["title"] = "Updated Event"
    entry.save!

    reloaded = Yerba.parse_file(File.join(event_dir, "event.yml"))
    assert_equal "Updated Event", reloaded.value_at("title")
  ensure
    FileUtils.rm_rf(tmp_dir)
  end
end
