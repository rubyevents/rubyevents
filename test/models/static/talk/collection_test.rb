# frozen_string_literal: true

require "test_helper"

class Static::Talk::CollectionTest < ActiveSupport::TestCase
  VIDEOS = [
    {
      "id" => "lightning-talks-testconf-2024",
      "title" => "Lightning Talks",
      "talks" => [
        {"id" => "one-testconf-2024", "title" => "One", "old_id" => "one-legacy", "video_id" => "one-video"},
        {"id" => "two-testconf-2024", "title" => "Two"}
      ]
    },
    {"id" => "jane-doe-testconf-2024", "title" => "Building Things"}
  ].freeze

  test "iterating yields every talk, nested talks right after their parent" do
    with_talks(VIDEOS) do |talks|
      assert_equal(
        ["lightning-talks-testconf-2024", "one-testconf-2024", "two-testconf-2024", "jane-doe-testconf-2024"],
        talks.map(&:id)
      )
      assert_equal 4, talks.count
    end
  end

  test "nested talks are regular talks with a parent" do
    with_talks(VIDEOS) do |talks|
      parent = talks.find_by(id: "lightning-talks-testconf-2024")
      child = talks.find_by(id: "one-testconf-2024")

      assert_instance_of Static::Talk, child
      assert_nil parent.parent
      assert_equal parent, child.parent
      assert_equal ["one-testconf-2024", "two-testconf-2024"], parent.talks.map(&:id)
      assert_empty child.talks
    end
  end

  test "where.missing(:parent) only yields talks without a parent, where.associated(:parent) the nested ones" do
    with_talks(VIDEOS) do |talks|
      assert_equal ["lightning-talks-testconf-2024", "jane-doe-testconf-2024"], talks.where.missing(:parent).map(&:id)
      assert_equal ["one-testconf-2024", "two-testconf-2024"], talks.where.associated(:parent).map(&:id)
    end
  end

  test "pairs pairs every talk with its nested talks" do
    with_talks(VIDEOS) do |talks|
      pairs = talks.pairs

      assert_equal 2, pairs.size
      assert_equal "lightning-talks-testconf-2024", pairs.first.first.id
      assert_equal ["one-testconf-2024", "two-testconf-2024"], pairs.first.last.map(&:id)
      assert_equal "jane-doe-testconf-2024", pairs.last.first.id
      assert_empty pairs.last.last
    end
  end

  test "ids and old_ids cover nested talks" do
    with_talks(VIDEOS) do |talks|
      assert_equal(
        ["lightning-talks-testconf-2024", "one-testconf-2024", "two-testconf-2024", "jane-doe-testconf-2024"],
        talks.ids
      )
      assert_equal ["one-legacy"], talks.old_ids
    end
  end

  test "find_by also finds nested talks" do
    with_talks(VIDEOS) do |talks|
      assert_equal "Two", talks.find_by(id: "two-testconf-2024").title
      assert_equal "one-testconf-2024", talks.find_by(video_id: "one-video").id
      assert talks.find_by(id: "two-testconf-2024").parent
    end
  end

  test "removed_ids come from the event.yml next to the videos.yml" do
    with_talks(VIDEOS) do |talks|
      File.write(File.join(File.dirname(talks.path), "event.yml"), %(---\nremoved_talk_ids:\n  - "gone-testconf-2024"\n))

      assert_equal ["gone-testconf-2024"], talks.removed_ids
    end
  end

  test "handles a file with an empty sequence" do
    with_talks([]) do |talks|
      assert_empty talks
      assert_empty talks.ids
    end
  end

  test "handles a file without a root" do
    with_temp_file("") do |path|
      talks = Static::Talk.in_file(path)

      assert_empty talks
      assert_empty talks.ids
    end
  end

  test "in_file works with an absolute path and an already parsed document" do
    with_temp_file(VIDEOS.to_yaml) do |path|
      document = Yerba.parse_file(path)
      talks = Static::Talk.in_file(path, document: document)

      assert_same document, talks.document
      assert_equal path, talks.path
      assert_equal 4, talks.count
    end
  end

  test "parse builds a collection from YAML content" do
    talks = Static::Talk.parse(VIDEOS.to_yaml)

    assert_equal 4, talks.ids.size
  end

  test "Static::Talk.all includes nested talks across all videos.yml files" do
    all = Static::Talk.all

    assert_operator all.count, :>, all.where.missing(:parent).count
    assert all.any?(&:parent)
    assert_equal all.files.sum { |file| file.ids.size }, all.ids.size
  end

  test "top_level is a scope on the model and on every collection of talks" do
    with_talks(VIDEOS) do |talks|
      assert_equal ["lightning-talks-testconf-2024", "jane-doe-testconf-2024"], talks.top_level.map(&:id)
      assert_equal ["jane-doe-testconf-2024"], talks.where(title: "Building Things").top_level.map(&:id)
    end

    assert_equal Static::Talk.all.where.missing(:parent).count, Static::Talk.top_level.count
  end

  private

  def with_talks(videos, &block)
    with_temp_file(videos.to_yaml) { |path| block.call(Static::Talk.in_file(path)) }
  end

  def with_temp_file(content)
    dir = Dir.mktmpdir
    path = File.join(dir, "data", "testconf", "testconf-2024", "videos.yml")
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
    yield path
  ensure
    FileUtils.rm_rf(dir)
  end
end
