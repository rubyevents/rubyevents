require "test_helper"

class Static::FileAssociationsTest < ActiveSupport::TestCase
  include StaticDataSandbox

  test "has_file returns the Pathname, whether the file exists or not" do
    with_event do |root, event|
      assert_equal Pathname.new(File.join(root, "app/assets/images/events/testconf/testconf-2024/avatar.webp")), event.avatar
      assert event.avatar.exist?
      assert_equal "avatar", event.avatar.read
      assert_not event.banner.exist?
    end
  end

  test "has_many of a file model lists the matching files as records" do
    with_event do |_root, event|
      assert_equal %w[stamp-1 stamp-2], event.stamps.map(&:basename)
      assert_equal [Static::EventStamp], event.stamps.map(&:class).uniq
      assert_equal %w[sticker], event.stickers.map(&:basename)
    end
  end

  test "Files with a glob lists the matching files" do
    with_event do |_root, event|
      files = Yerba::Record::Files.new(event.images.path, glob: "stamp*.webp")

      assert_equal %w[stamp-1.webp stamp-2.webp], files.map { |file| file.basename.to_s }
      assert_equal 2, files.count
    end
  end

  test "has_file with ** finds a file in any subdirectory, with attributes as segments" do
    with_event do |root, _event|
      talks = Static::Talk.in_file(File.join(root, "data/testconf/testconf-2024/videos.yml"))
      thumbnails = File.join(root, "app/assets/images/thumbnails/testconf-2024")

      assert_equal Pathname.new(File.join(thumbnails, "opening.webp")), talks.find_by(id: "opening").thumbnail
      assert_equal Pathname.new(File.join(thumbnails, "panel/panel-one.webp")), talks.find_by(id: "panel-one").thumbnail
      assert_equal Pathname.new(File.join(thumbnails, "closing.webp")), talks.find_by(id: "closing").thumbnail
      assert_not talks.find_by(id: "closing").thumbnail.exist?
    end
  end

  test "saving a collection moves the files named by changed attributes" do
    with_event do |root, _event|
      talks = Static::Talk.in_file(File.join(root, "data/testconf/testconf-2024/videos.yml"))
      thumbnails = File.join(root, "app/assets/images/thumbnails/testconf-2024")

      talks.find_by(id: "opening").tap { |talk| talk["video_id"] = "welcome" }
      talks.find_by(id: "panel").tap { |talk| talk["id"] = "panel-discussion" }
      talks.find_by(id: "panel-one").tap { |talk| talk["video_id"] = "panel-first" }
      talks.save!

      assert File.exist?(File.join(thumbnails, "welcome.webp"))
      assert_not File.exist?(File.join(thumbnails, "opening.webp"))
      assert File.exist?(File.join(thumbnails, "panel-discussion/panel-first.webp"))
      assert_not Dir.exist?(File.join(thumbnails, "panel"))
    end
  end

  test "renaming an event moves its images, stamps and thumbnails" do
    with_event do |root, event|
      event.rename!("testconf-2025")

      assert_equal %w[stamp-1 stamp-2], event.stamps.map(&:basename)
      assert event.avatar.exist?
      assert File.exist?(File.join(root, "app/assets/images/thumbnails/testconf-2025/opening.webp"))
    end
  end

  private

  def with_event
    with_static_data_dir do |root|
      write(root, "data/testconf/series.yml", %(---\nid: "testconf"\nname: "TestConf"\n))
      write(root, "data/testconf/testconf-2024/event.yml", %(---\nid: "testconf-2024"\ntitle: "TestConf 2024"\nkind: "conference"\n))
      write(root, "data/testconf/testconf-2024/videos.yml", <<~YAML)
        ---
        - id: "opening"
          title: "Opening"
          video_provider: "not_recorded"
          video_id: "opening"

        - id: "panel"
          title: "Panel"
          video_provider: "children"
          video_id: "panel"
          talks:
            - id: "panel-one"
              title: "Panel One"
              video_provider: "not_recorded"
              video_id: "panel-one"

        - id: "closing"
          title: "Closing"
          video_provider: "not_recorded"
          video_id: "closing"
      YAML

      images = "app/assets/images/events/testconf/testconf-2024"
      %w[avatar.webp sticker.webp stamp-1.webp stamp-2.webp].each { |file| write(root, "#{images}/#{file}", file.delete_suffix(".webp")) }
      write(root, "app/assets/images/thumbnails/testconf-2024/opening.webp", "opening")
      write(root, "app/assets/images/thumbnails/testconf-2024/panel/panel-one.webp", "panel-one")

      yield root, Static::Event.in_file(File.join(root, "data/testconf/testconf-2024/event.yml")).first
    end
  end

  def write(root, path, content)
    path = File.join(root, path)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
  end
end
