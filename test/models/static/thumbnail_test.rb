# frozen_string_literal: true

require "test_helper"

class Static::ThumbnailTest < ActiveSupport::TestCase
  setup do
    @root = Dir.mktmpdir
    @previous_root = Static::Thumbnail.instance_variable_get(:@root)
    Static::Thumbnail.root = @root
    Static::Thumbnail.unload!
  end

  teardown do
    Static::Thumbnail.root = @previous_root
    Static::Thumbnail.unload!
    FileUtils.rm_rf(@root) if @root
  end

  test "reads its video id and directory from its path" do
    thumbnail = write_thumbnail("testconf-2024/lightning-talk-testconf-2024/jane-doe-testconf-2024")

    assert_equal "jane-doe-testconf-2024", thumbnail.video_id
    assert_equal "testconf-2024/lightning-talk-testconf-2024", thumbnail.directory
    assert_equal [thumbnail], Static::Thumbnail.all.to_a
  end

  test "flags a thumbnail without a matching talk" do
    assert_equal ["Redundant thumbnail: no talk with video_id 'unknown-talk' exists, this file can be deleted"],
      lint_errors("testconf-2024/unknown-talk", lookup: {})
  end

  test "does not flag a thumbnail in its event directory" do
    assert_empty lint_errors("testconf-2024/jane-doe-testconf-2024", lookup: lookup_for("jane-doe-testconf-2024"))
  end

  test "flags a thumbnail in the wrong event directory" do
    assert_equal ["Redundant thumbnail: talk 'jane-doe-testconf-2024' belongs to 'testconf-2024', move this file to thumbnails/testconf-2024/jane-doe-testconf-2024.webp"],
      lint_errors("otherconf-2023/jane-doe-testconf-2024", lookup: lookup_for("jane-doe-testconf-2024"))
  end

  test "flags a thumbnail directly in the thumbnails directory" do
    write_thumbnail("jane-doe-testconf-2024")

    assert_equal 1, Static::Thumbnail.all.count
    assert_equal ["Redundant thumbnail: talk 'jane-doe-testconf-2024' belongs to 'testconf-2024', move this file to thumbnails/testconf-2024/jane-doe-testconf-2024.webp"],
      lint_errors("jane-doe-testconf-2024", lookup: lookup_for("jane-doe-testconf-2024"))
  end

  test "does not flag a sub-talk thumbnail in its parent talk directory" do
    lookup = lookup_for("jane-doe-testconf-2024", parent_id: "lightning-talk-testconf-2024")

    assert_empty lint_errors("testconf-2024/lightning-talk-testconf-2024/jane-doe-testconf-2024", lookup: lookup)
  end

  test "flags a sub-talk thumbnail outside its parent talk directory" do
    lookup = lookup_for("jane-doe-testconf-2024", parent_id: "lightning-talk-testconf-2024")

    assert_equal ["Redundant thumbnail: talk 'jane-doe-testconf-2024' belongs to 'testconf-2024/lightning-talk-testconf-2024', move this file to thumbnails/testconf-2024/lightning-talk-testconf-2024/jane-doe-testconf-2024.webp"],
      lint_errors("testconf-2024/jane-doe-testconf-2024", lookup: lookup)
  end

  test "flags a thumbnail for a remote provider talk without a start_cue" do
    lookup = lookup_for("jane-doe-testconf-2024", "video_provider" => "youtube", "start_cue" => nil)

    assert_equal ["Redundant thumbnail: talk 'jane-doe-testconf-2024' has no start_cue and its youtube thumbnail is available remotely, this file can be deleted"],
      lint_errors("testconf-2024/jane-doe-testconf-2024", lookup: lookup)
  end

  test "does not flag a thumbnail for a remote provider talk with a start_cue" do
    lookup = lookup_for("jane-doe-testconf-2024", "video_provider" => "youtube", "start_cue" => "00:05")

    assert_empty lint_errors("testconf-2024/jane-doe-testconf-2024", lookup: lookup)
  end

  private

  def lookup_for(video_id, parent_id: nil, **attributes)
    talk = Static::Talk.new({"video_provider" => "not_recorded", "start_cue" => "00:00"}.merge(attributes))

    {video_id => {talk: talk, event_slug: "testconf-2024", parent_id: parent_id}}
  end

  def lint_errors(path, lookup:)
    thumbnail = write_thumbnail(path)

    Static::Thumbnail.stub(:talk_lookup, lookup) do
      thumbnail.valid?(:lint)
    end

    thumbnail.errors.full_messages
  end

  def write_thumbnail(path)
    file_path = File.join(@root, "app/assets/images/thumbnails", "#{path}.webp")
    FileUtils.mkdir_p(File.dirname(file_path))
    File.write(file_path, "webp")

    Static::Thumbnail.new(file_path)
  end
end
