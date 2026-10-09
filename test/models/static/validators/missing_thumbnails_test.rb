# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"

class Static::Validators::MissingThumbnailsTest < ActiveSupport::TestCase
  def write_videos(dir, contents)
    FileUtils.mkdir_p(dir)
    path = File.join(dir, "videos.yml")
    File.write(path, contents)
    path
  end

  def child(video_id:, start_cue: "01:00", speakers: ["Jane Doe"])
    speaker_lines = speakers.map { |name| "        - #{name.inspect}" }.join("\n")
    <<~YAML
      - id: "parent-test-event"
        title: "Meta"
        video_id: "PARENT123"
        talks:
          - id: "#{video_id}"
            title: "Talk"
            video_id: "#{video_id}"
            start_cue: #{start_cue.inspect}
            speakers:
      #{speaker_lines}
    YAML
  end

  test "applicable? only for videos.yml files" do
    Dir.mktmpdir do |root|
      path = write_videos(File.join(root, "series", "test-event"), "[]\n")
      assert Static::Validators::MissingThumbnails.new(file_path: path).applicable?
    end

    assert_not Static::Validators::MissingThumbnails.new(file_path: Rails.root.join("data/blue-ridge-ruby/series.yml").to_s).applicable?
  end

  test "flags a child talk with a speaker and start_cue but no thumbnail" do
    Dir.mktmpdir do |root|
      path = write_videos(File.join(root, "series", "test-event"), child(video_id: "jane-doe-test-event"))

      errors = Static::Validators::MissingThumbnails.new(file_path: path).errors

      assert_equal 1, errors.size
      assert_match "jane-doe-test-event", errors.first.message
    end
  end

  test "no error when the thumbnail exists" do
    slug = "missing-thumbnails-test-event"
    thumbnail = Rails.root.join("app/assets/images/thumbnails", slug, "parent-test-event", "jane-doe-test-event.webp")
    FileUtils.mkdir_p(File.dirname(thumbnail))
    FileUtils.touch(thumbnail)

    Dir.mktmpdir do |root|
      path = write_videos(File.join(root, "series", slug), child(video_id: "jane-doe-test-event"))

      assert_empty Static::Validators::MissingThumbnails.new(file_path: path).errors
    end
  ensure
    FileUtils.rm_rf(Rails.root.join("app/assets/images/thumbnails", slug))
  end

  test "ignores speaker-less segments such as open mics" do
    Dir.mktmpdir do |root|
      path = write_videos(File.join(root, "series", "test-event"), child(video_id: "open-mic-test-event", speakers: []))

      assert_empty Static::Validators::MissingThumbnails.new(file_path: path).errors
    end
  end

  test "ignores talks without a usable start_cue" do
    Dir.mktmpdir do |root|
      path = write_videos(File.join(root, "series", "test-event"), child(video_id: "jane-doe-test-event", start_cue: "TODO"))

      assert_empty Static::Validators::MissingThumbnails.new(file_path: path).errors
    end
  end
end
