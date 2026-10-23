# frozen_string_literal: true

require "test_helper"

class Static::RecordingsPublishedDateValidatorTest < ActiveSupport::TestCase
  include StaticDataSandbox

  test "flags a recordings_published_date on a meetup" do
    assert_equal ["recordings_published_date (2024-01-01) must not be set for meetups"], errors_for({"kind" => "meetup", "recordings_published_date" => "2024-01-01"}, watchable(3))
  end

  test "a meetup without a recordings_published_date is valid" do
    assert_empty errors_for({"kind" => "meetup"}, watchable(3))
  end

  test "valid when the majority is published and the date is not too early" do
    event = {"kind" => "conference", "end_date" => "2024-12-31", "recordings_published_date" => "2025-01-03"}

    assert_empty errors_for(event, watchable(3, dates: %w[2025-01-01 2025-01-02 2025-01-03]))
  end

  test "requires a recordings_published_date when the majority is published" do
    assert_equal ["recordings_published_date is required when the majority of talks are published (3/3 resolvable talks published)"], errors_for({"kind" => "conference", "end_date" => "2024-12-31"}, watchable(3))
  end

  test "forbids a recordings_published_date when the majority is not published" do
    event = {"kind" => "conference", "end_date" => "2024-12-31", "recordings_published_date" => "2025-01-01"}

    assert_equal ["recordings_published_date (2025-01-01) must not be set unless the majority of talks are published (1/4 resolvable talks published)"], errors_for(event, watchable(1, dates: ["2025-01-01"]) + providers("scheduled", 3))
  end

  test "forbids a recordings_published_date when there is no videos.yml or it has no talks" do
    event = {"kind" => "conference", "end_date" => "2024-12-31", "recordings_published_date" => "2025-01-01"}
    message = "recordings_published_date (2025-01-01) must not be set unless the majority of talks are published (0/0 resolvable talks published)"

    assert_equal [message], errors_for(event, nil)
    assert_equal [message], errors_for(event, [])
  end

  test "no videos.yml and no recordings_published_date is valid" do
    assert_empty errors_for({"kind" => "conference", "end_date" => "2024-12-31"}, nil)
  end

  test "talks that are not recorded or published don't count towards the majority" do
    videos = watchable(2, dates: %w[2025-01-01 2025-01-02]) + providers("not_recorded", 5)

    assert_equal ["recordings_published_date is required when the majority of talks are published (2/2 resolvable talks published)"], errors_for({"kind" => "conference", "end_date" => "2024-12-31"}, videos)
  end

  test "flags a recordings_published_date before the end_date" do
    event = {"kind" => "conference", "end_date" => "2025-06-01", "recordings_published_date" => "2025-05-01"}

    assert_includes errors_for(event, watchable(3, dates: %w[2025-01-01 2025-01-02 2025-01-03])), "recordings_published_date (2025-05-01) must not be before end_date (2025-06-01)"
  end

  test "flags a recordings_published_date before the P90 of the video published_at dates" do
    event = {"kind" => "conference", "end_date" => "2024-12-31", "recordings_published_date" => "2025-01-15"}

    assert_equal ["recordings_published_date (2025-01-15) must not be before the P90 of the video published_at dates (2025-03-01)"], errors_for(event, watchable(3, dates: %w[2025-01-01 2025-02-01 2025-03-01]))
  end

  test "flags a recordings_published_date on an event that has not started yet" do
    event = {"kind" => "conference", "start_date" => "2099-01-01", "recordings_published_date" => "2099-01-02"}

    assert_equal ["recordings_published_date (2099-01-02) must not be set for an event that has not started yet (start_date 2099-01-01 is in the future)"], errors_for(event, providers("scheduled", 3))
  end

  test "a future event without a recordings_published_date is valid" do
    assert_empty errors_for({"kind" => "conference", "start_date" => "2099-01-01"}, providers("scheduled", 3))
  end

  test "percentile ignores a single late straggler" do
    dates = Array.new(9) { Date.new(2020, 1, 1) } + [Date.new(2025, 1, 1)]

    assert_equal Date.new(2020, 1, 1), Static::RecordingsPublishedDateValidator.percentile(dates)
  end

  test "percentile of an empty list is nil" do
    assert_nil Static::RecordingsPublishedDateValidator.percentile([])
  end

  private

  def watchable(count, dates: nil)
    Array.new(count) do |index|
      {"video_provider" => "youtube", "published_at" => dates ? dates[index] : "2025-01-0#{index + 1}"}
    end
  end

  def providers(provider, count)
    Array.new(count) { {"video_provider" => provider} }
  end

  def errors_for(event, videos)
    with_static_data_dir do |root|
      path = File.join(root, "data", "testconf", "testconf-2025", "event.yml")
      FileUtils.mkdir_p(File.dirname(path))
      Yerba::Document.from({"id" => "testconf-2025", "title" => "TestConf"}.merge(event)).save_to!(path)

      unless videos.nil?
        talks = videos.each_with_index.map { |video, index| {"id" => "talk-#{index}", "title" => "Talk #{index}"}.merge(video) }
        Yerba::Document.from(talks).save_to!(File.join(File.dirname(path), "videos.yml"))
      end

      event = Static::Event.in_file(path).first
      event.valid?(:lint)
      event.errors.full_messages_for(:recordings_published_date)
    end
  end
end
