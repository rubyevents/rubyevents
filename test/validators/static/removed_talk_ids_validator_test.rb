# frozen_string_literal: true

require "test_helper"

class Static::RemovedTalkIdsValidatorTest < ActiveSupport::TestCase
  include StaticDataSandbox

  MESSAGE = %(id "jane-doe-testconf-2024" is listed under `removed_talk_ids`, but it is still in videos.yml. Either drop it from `removed_talk_ids`, or remove the talk from videos.yml.)

  test "an event without removed_talk_ids is valid" do
    with_event(removed_talk_ids: [], videos: [{"id" => "jane-doe-testconf-2024", "title" => "A"}]) do |event|
      assert_empty removed_talk_id_errors(event)
    end
  end

  test "a removed id that is gone from videos.yml is valid" do
    with_event(removed_talk_ids: ["jane-doe-testconf-2024"], videos: [{"id" => "john-smith-testconf-2024", "title" => "B"}]) do |event|
      assert_empty removed_talk_id_errors(event)
    end
  end

  test "flags a removed id that is still in videos.yml" do
    with_event(removed_talk_ids: ["jane-doe-testconf-2024"], videos: [{"id" => "jane-doe-testconf-2024", "title" => "A"}]) do |event|
      assert_equal [MESSAGE], removed_talk_id_errors(event)
      assert_equal 5, event.error_location(event.errors.find { |error| error.message == MESSAGE }).start_line
    end
  end

  test "flags a removed id that survives as an old_id" do
    videos = [{"id" => "jane-doe-keynote-testconf-2024", "old_id" => "jane-doe-testconf-2024", "title" => "A"}]

    with_event(removed_talk_ids: ["jane-doe-testconf-2024"], videos: videos) do |event|
      assert_equal [MESSAGE], removed_talk_id_errors(event)
    end
  end

  test "flags a removed id nested under a parent talk" do
    videos = [{"id" => "lightning-talks-testconf-2024", "title" => "Lightning Talks", "talks" => [{"id" => "jane-doe-testconf-2024", "title" => "A"}]}]

    with_event(removed_talk_ids: ["jane-doe-testconf-2024"], videos: videos) do |event|
      assert_equal [MESSAGE], removed_talk_id_errors(event)
    end
  end

  test "only flags the ids that are still present" do
    with_event(removed_talk_ids: ["gone-testconf-2024", "jane-doe-testconf-2024"], videos: [{"id" => "jane-doe-testconf-2024", "title" => "A"}]) do |event|
      assert_equal [MESSAGE], removed_talk_id_errors(event)
      assert_equal 6, event.error_location(event.errors.find { |error| error.message == MESSAGE }).start_line
    end
  end

  test "an event without a videos.yml is valid" do
    with_event(removed_talk_ids: ["jane-doe-testconf-2024"], videos: nil) do |event|
      assert_empty removed_talk_id_errors(event)
    end
  end

  private

  def removed_talk_id_errors(event)
    event.valid?(:lint)
    event.errors.full_messages.select { |message| message.include?("`removed_talk_ids`") }
  end

  def with_event(removed_talk_ids:, videos:)
    with_static_data_dir do |root|
      path = File.join(root, "data", "testconf", "testconf-2024", "event.yml")
      FileUtils.mkdir_p(File.dirname(path))

      lines = ["---", %(id: "testconf-2024"), %(title: "TestConf 2024")]
      lines += ["removed_talk_ids:", *removed_talk_ids.map { |id| %(  - "#{id}") }] if removed_talk_ids.any?
      File.write(path, lines.join("\n") + "\n")

      Yerba::Document.from(videos).save_to!(File.join(File.dirname(path), "videos.yml")) if videos

      yield Static::Event.in_file(path).first
    end
  end
end
