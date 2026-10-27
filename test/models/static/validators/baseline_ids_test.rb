# frozen_string_literal: true

require "test_helper"

class Static::Validators::BaselineIdsTest < ActiveSupport::TestCase
  include StaticDataSandbox

  test "accepts ids that are still there or kept as former ids" do
    with_data do
      stub_baseline(
        series: ["data/testrb/series.yml", "data/test-rb/series.yml"],
        events: {"testrb-2026-01-14" => ["data/testrb/testrb-2026-01-14"], "testrb-meetup" => ["data/testrb/testrb-meetup"], "testrb-brigade" => ["data/testrb/testrb-brigade"]},
        talks: [["jane-doe-testrb-2026-01-14", "data/testrb/testrb-meetup/videos.yml", 3], ["jane-doe-testrb-meetup-january-2026", "data/testrb/testrb-meetup/videos.yml", 9],
          ["testrb-meetup-january-2026", "data/testrb/testrb-meetup/videos.yml", 2], ["removed-talk", "data/testrb/testrb-meetup/videos.yml", 20]]
      ) do
        assert_empty Static::Validators::BaselineIds.errors
      end
    end
  end

  test "flags an event and a talk of the baseline that are gone, at their place on the baseline" do
    with_data do
      stub_baseline(events: {"testrb-workshop" => ["data/testrb/testrb-workshop"]}, talks: [["john-doe-testrb-meetup-may-2025", "data/testrb/testrb-meetup/videos.yml", 42]]) do
        errors = Static::Validators::BaselineIds.errors

        assert_equal ["data/testrb/testrb-workshop/event.yml", "data/testrb/testrb-meetup/videos.yml"], errors.map(&:file_path)
        assert_includes errors.first.message, %(event "testrb-workshop" of abc123 is gone)
        assert_includes errors.last.message, %(talk "john-doe-testrb-meetup-may-2025" of abc123 is gone)
        assert_equal 42, errors.last.line
      end
    end
  end

  test "flags a series of the baseline that was renamed without keeping its id" do
    with_data do
      stub_baseline(series: ["data/testrb-brigade/series.yml"], events: {}, talks: []) do
        errors = Static::Validators::BaselineIds.errors

        assert_equal ["data/testrb-brigade/series.yml"], errors.map(&:file_path)
        assert_includes errors.first.message, %(series "testrb-brigade" of abc123 is gone)
      end
    end
  end

  test "does not flag anything without a baseline" do
    with_data do
      Static::Validators::BaselineIds.stub(:baseline_ref, nil) do
        assert_empty Static::Validators::BaselineIds.errors
      end
    end
  end

  private

  def stub_baseline(events:, talks:, series: [], &block)
    Static::Validators::BaselineIds.stub(:baseline_ref, "abc123") do
      Static::Validators::BaselineIds.stub(:baseline_series_paths, series) do
        Static::Validators::BaselineIds.stub(:baseline_event_directories, events) do
          Static::Validators::BaselineIds.stub(:baseline_talks, talks, &block)
        end
      end
    end
  end

  def with_data
    with_static_data_dir do |dir|
      series_dir = File.join(dir, "data", "testrb")
      event_dir = File.join(series_dir, "testrb-2026-01-14")
      FileUtils.mkdir_p(event_dir)

      File.write(File.join(series_dir, "series.yml"), Yerba::Document.from({"id" => "testrb", "old_ids" => ["test-rb"], "name" => "Test.rb", "kind" => "meetup", "old_event_ids" => ["testrb-meetup"], "removed_talk_ids" => ["removed-talk"]}).to_s)
      File.write(File.join(event_dir, "event.yml"), Yerba::Document.from({"id" => "testrb-2026-01-14", "old_ids" => ["testrb-brigade"], "old_talk_ids" => ["testrb-meetup-january-2026"], "title" => "Test.rb Meetup January 2026", "kind" => "meetup", "start_date" => "2026-01-14", "end_date" => "2026-01-14"}).to_s)
      File.write(File.join(event_dir, "videos.yml"), Yerba::Document.from([{"id" => "jane-doe-testrb-2026-01-14", "old_id" => "jane-doe-testrb-meetup-january-2026", "title" => "Talk", "date" => "2026-01-14"}]).to_s)

      yield
    end
  end
end
