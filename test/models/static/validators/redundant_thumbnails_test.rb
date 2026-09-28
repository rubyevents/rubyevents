# frozen_string_literal: true

require "test_helper"

class Static::Validators::RedundantThumbnailsTest < ActiveSupport::TestCase
  test "applicable? returns true for a webp file in an event directory" do
    with_temp_thumbnail("testconf-2024") do |path|
      assert Static::Validators::RedundantThumbnails.new(file_path: path).applicable?
    end
  end

  test "applicable? returns true for a webp file at the thumbnails root" do
    with_temp_thumbnail(nil) do |path|
      assert Static::Validators::RedundantThumbnails.new(file_path: path).applicable?
    end
  end

  test "flags a thumbnail without a matching talk" do
    with_temp_thumbnail("testconf-2024", name: "unknown-talk") do |path|
      Static::Validators::RedundantThumbnails.stub(:talk_lookup, {}) do
        errors = Static::Validators::RedundantThumbnails.new(file_path: path).errors

        assert_equal 1, errors.size
        assert_includes errors.first.message, "no talk with video_id 'unknown-talk' exists"
      end
    end
  end

  test "does not flag a thumbnail in its event directory" do
    with_temp_thumbnail("testconf-2024", name: "jane-doe-testconf-2024") do |path|
      Static::Validators::RedundantThumbnails.stub(:talk_lookup, lookup_for("jane-doe-testconf-2024")) do
        assert_empty Static::Validators::RedundantThumbnails.new(file_path: path).errors
      end
    end
  end

  test "flags a thumbnail outside its event directory" do
    with_temp_thumbnail(nil, name: "jane-doe-testconf-2024") do |path|
      Static::Validators::RedundantThumbnails.stub(:talk_lookup, lookup_for("jane-doe-testconf-2024")) do
        errors = Static::Validators::RedundantThumbnails.new(file_path: path).errors

        assert_equal 1, errors.size
        assert_includes errors.first.message, "move this file to thumbnails/testconf-2024/jane-doe-testconf-2024.webp"
      end
    end
  end

  test "flags a thumbnail in the wrong event directory" do
    with_temp_thumbnail("otherconf-2023", name: "jane-doe-testconf-2024") do |path|
      Static::Validators::RedundantThumbnails.stub(:talk_lookup, lookup_for("jane-doe-testconf-2024")) do
        errors = Static::Validators::RedundantThumbnails.new(file_path: path).errors

        assert_equal 1, errors.size
        assert_includes errors.first.message, "move this file to thumbnails/testconf-2024/jane-doe-testconf-2024.webp"
      end
    end
  end

  test "does not flag a sub-talk thumbnail in its parent talk directory" do
    lookup = lookup_for("jane-doe-testconf-2024", parent_id: "lightning-talk-testconf-2024")

    with_temp_thumbnail("testconf-2024/lightning-talk-testconf-2024", name: "jane-doe-testconf-2024") do |path|
      Static::Validators::RedundantThumbnails.stub(:talk_lookup, lookup) do
        assert_empty Static::Validators::RedundantThumbnails.new(file_path: path).errors
      end
    end
  end

  test "flags a sub-talk thumbnail outside its parent talk directory" do
    lookup = lookup_for("jane-doe-testconf-2024", parent_id: "lightning-talk-testconf-2024")

    with_temp_thumbnail("testconf-2024", name: "jane-doe-testconf-2024") do |path|
      Static::Validators::RedundantThumbnails.stub(:talk_lookup, lookup) do
        errors = Static::Validators::RedundantThumbnails.new(file_path: path).errors

        assert_equal 1, errors.size
        assert_includes errors.first.message, "move this file to thumbnails/testconf-2024/lightning-talk-testconf-2024/jane-doe-testconf-2024.webp"
      end
    end
  end

  test "flags a thumbnail for a remote provider talk without a start_cue" do
    lookup = lookup_for("jane-doe-testconf-2024", "video_provider" => "youtube", "start_cue" => nil)

    with_temp_thumbnail("testconf-2024", name: "jane-doe-testconf-2024") do |path|
      Static::Validators::RedundantThumbnails.stub(:talk_lookup, lookup) do
        errors = Static::Validators::RedundantThumbnails.new(file_path: path).errors

        assert_equal 1, errors.size
        assert_includes errors.first.message, "available remotely"
      end
    end
  end

  private

  def lookup_for(video_id, parent_id: nil, **attributes)
    talk = Static::Video.new({"video_provider" => "not_recorded", "start_cue" => "00:00"}.merge(attributes))

    {video_id => {talk: talk, event_slug: "testconf-2024", parent_id: parent_id}}
  end

  def with_temp_thumbnail(event_slug, name: "some-talk")
    dir = Dir.mktmpdir
    segments = [dir, "app", "assets", "images", "thumbnails", event_slug, "#{name}.webp"].compact
    path = File.join(*segments)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "webp")
    yield path
  ensure
    FileUtils.rm_rf(dir)
  end
end
