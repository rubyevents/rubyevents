require "test_helper"

class Static::RenameTest < ActiveSupport::TestCase
  include StaticDataSandbox

  test "rename! moves the event folder and its assets, and updates the id" do
    with_event do |root, event|
      renamed = event.rename!("testconf-2025")

      assert_equal({series_id: "testconf", id: "testconf-2025"}, renamed.path_params)
      assert_equal "testconf-2025", renamed["id"]
      assert_equal ["Opening"], renamed.talks.map { |talk| talk["title"] }
      assert_not File.exist?(File.join(root, "data/testconf/testconf-2024"))
      assert File.exist?(File.join(root, "app/assets/images/events/testconf/testconf-2025/card.webp"))
      assert File.exist?(File.join(root, "app/assets/images/thumbnails/testconf-2025/opening.webp"))
      assert_includes File.read(File.join(root, "data/testconf/testconf-2025/event.yml")), %(id: "testconf-2025")
    end
  end

  test "has_files reads the directories named by the record's path" do
    with_event do |root, event|
      assert_equal Pathname.new(File.join(root, "app/assets/images/events/testconf/testconf-2024")), event.images.path
      assert_equal %w[card.webp], event.images.map { |file| file.basename.to_s }
      assert_equal event.images.path.join("card.webp"), event.images["card.webp"]
      assert_nil event.images["banner.webp"]
      assert event.thumbnails["opening.webp"]
      assert_equal event.thumbnails.first, event.thumbnails["opening.webp"]
      assert_equal 1, event.images.count
      assert_equal [], Static::EventSeries.in_file(File.join(root, "data/testconf/series.yml")).first.images.to_a

      renamed = event.rename!("testconf-2025")

      assert_equal Pathname.new(File.join(root, "app/assets/images/events/testconf/testconf-2025")), renamed.images.path
      assert renamed.images["card.webp"]
    end
  end

  test "saving a changed id moves the folder and keeps the record usable" do
    with_event do |root, event|
      event["id"] = "testconf-2025"
      event.save!

      assert_equal({series_id: "testconf", id: "testconf-2025"}, event.path_params)
      assert_equal File.join(root, "data/testconf/testconf-2025/event.yml"), event.file_path
      assert_equal ["Opening"], event.talks.map { |talk| talk["title"] }
      assert File.exist?(File.join(root, "app/assets/images/thumbnails/testconf-2025/opening.webp"))

      event["title"] = "TestConf 2025"
      event.save!

      assert_includes File.read(File.join(root, "data/testconf/testconf-2025/event.yml")), %(title: "TestConf 2025")
    end
  end

  test "saving a changed series_id moves the event to the other series" do
    with_event do |root, event|
      FileUtils.mkdir_p(File.join(root, "data/otherconf"))

      assert_equal "testconf", event.series_id

      event.series_id = "otherconf"
      assert_equal "otherconf", event.series_id
      assert File.exist?(File.join(root, "data/testconf/testconf-2024/event.yml"))

      event.save!

      assert_equal({series_id: "otherconf", id: "testconf-2024"}, event.path_params)
      assert_equal "otherconf", event.series_slug
      assert File.exist?(File.join(root, "data/otherconf/testconf-2024/event.yml"))
      assert File.exist?(File.join(root, "app/assets/images/events/otherconf/testconf-2024/card.webp"))
      assert_not_includes File.read(event.file_path), "series_id"
    end
  end

  test "moving an event into a series that doesn't exist explains how to create it and moves nothing" do
    with_event do |root, event|
      event.series_id = "newconf"

      error = assert_raises(ArgumentError) { event.save! }

      assert_includes error.message, %(The series "newconf" doesn't exist yet (no data/newconf/series.yml))
      assert_includes error.message, %(Static::EventSeries.create(name: "Newconf", slug: "newconf"))
      assert File.exist?(File.join(root, "data/testconf/testconf-2024/event.yml"))
      assert_not File.exist?(File.join(root, "data/newconf"))
    end
  end

  test "saving other changes leaves the folder in place" do
    with_event do |root, event|
      event["title"] = "Renamed"
      event.save!

      assert File.exist?(File.join(root, "data/testconf/testconf-2024/event.yml"))
      assert_equal({series_id: "testconf", id: "testconf-2024"}, event.path_params)
    end
  end

  test "move_to! moves the event folder to another series" do
    with_event do |root, event|
      FileUtils.mkdir_p(File.join(root, "data/otherconf"))

      moved = event.move_to!(series_id: "otherconf")

      assert_equal({series_id: "otherconf", id: "testconf-2024"}, moved.path_params)
      assert File.exist?(File.join(root, "data/otherconf/testconf-2024/videos.yml"))
      assert File.exist?(File.join(root, "app/assets/images/events/otherconf/testconf-2024/card.webp"))
      assert File.exist?(File.join(root, "app/assets/images/thumbnails/testconf-2024/opening.webp"))
    end
  end

  test "rename! of a series moves its folder with all its events" do
    with_event do |root, _event|
      series = Static::EventSeries.in_file(File.join(root, "data/testconf/series.yml")).first

      renamed = series.rename!("newconf")

      assert_equal "newconf", renamed["id"]
      assert_equal ["testconf-2024"], renamed.events.map(&:id)
      assert File.exist?(File.join(root, "data/newconf/testconf-2024/event.yml"))
      assert File.exist?(File.join(root, "app/assets/images/events/newconf/testconf-2024/card.webp"))
    end
  end

  test "rename! refuses to overwrite an existing folder and moves nothing" do
    with_event do |root, event|
      FileUtils.mkdir_p(File.join(root, "data/testconf/testconf-2025"))

      assert_raises(ArgumentError) { event.rename!("testconf-2025") }
      assert File.exist?(File.join(root, "data/testconf/testconf-2024/event.yml"))
      assert_includes File.read(File.join(root, "data/testconf/testconf-2024/event.yml")), %(id: "testconf-2024")
    end
  end

  test "move_to! needs a directory named by :id" do
    with_event do |root, _event|
      talk = Static::Talk.in_file(File.join(root, "data/testconf/testconf-2024/videos.yml")).first

      assert_raises(ArgumentError) { talk.move_to!(event_id: "testconf-2025") }
    end
  end

  private

  def with_event
    with_static_data_dir do |root|
      write(root, "data/testconf/series.yml", %(---\nid: "testconf"\nname: "TestConf"\n))
      write(root, "data/testconf/testconf-2024/event.yml", %(---\nid: "testconf-2024"\ntitle: "TestConf 2024"\nkind: "conference"\n))
      write(root, "data/testconf/testconf-2024/videos.yml", %(---\n- id: "opening"\n  title: "Opening"\n))
      write(root, "app/assets/images/events/testconf/testconf-2024/card.webp", "webp")
      write(root, "app/assets/images/thumbnails/testconf-2024/opening.webp", "webp")

      yield root, Static::Event.in_file(File.join(root, "data/testconf/testconf-2024/event.yml")).first
    end
  end

  def write(root, path, content)
    path = File.join(root, path)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
  end
end
