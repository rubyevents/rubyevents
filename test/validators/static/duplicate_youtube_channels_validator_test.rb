# frozen_string_literal: true

require "test_helper"

class Static::DuplicateYouTubeChannelsValidatorTest < ActiveSupport::TestCase
  include StaticDataSandbox

  test "channels that are not on the series are valid" do
    with_event(series_channels: [{"id" => "UC123", "name" => "TestConf"}], event_channels: [{"id" => "UC456", "name" => "TestConf 2025"}]) do |event|
      assert_empty channel_errors(event)
    end
  end

  test "an event without a series is valid" do
    with_event(series_channels: nil, event_channels: [{"id" => "UC123", "name" => "TestConf"}]) do |event|
      assert_empty channel_errors(event)
    end
  end

  test "flags a channel that is already defined on the series" do
    channels = [{"id" => "UC456", "name" => "Other"}, {"id" => "UC123", "name" => "TestConf"}]

    with_event(series_channels: [{"id" => "UC123", "name" => "TestConf"}], event_channels: channels) do |event|
      assert_equal [%(youtube_channels contains channel "UC123" (TestConf) which is already defined in series.yml — remove it from event.yml)], channel_errors(event)
      assert_equal 7, event.error_location(event.errors.where(:youtube_channels).first).start_line
    end
  end

  private

  def channel_errors(event)
    event.valid?(:lint)
    event.errors.full_messages_for(:youtube_channels)
  end

  def with_event(series_channels:, event_channels:)
    with_static_data_dir do |root|
      path = File.join(root, "data", "testconf", "testconf-2025", "event.yml")
      FileUtils.mkdir_p(File.dirname(path))

      Yerba::Document.from({"id" => "testconf", "name" => "TestConf", "youtube_channels" => series_channels}).save_to!(File.join(root, "data", "testconf", "series.yml")) if series_channels
      Yerba::Document.from({"id" => "testconf-2025", "title" => "TestConf 2025", "youtube_channels" => event_channels}).save_to!(path)

      yield Static::Event.in_file(path).first
    end
  end
end
