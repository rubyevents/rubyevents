# frozen_string_literal: true

require "test_helper"

class EventLookupToolTest < ActiveSupport::TestCase
  include StaticDataSandbox

  def build_tool
    EventLookupTool.new
  end

  def write_event(root, series_id:, id:, title:, kind:, location:, start_date:, end_date:)
    directory = File.join(root, "data", series_id, id)
    FileUtils.mkdir_p(directory)
    File.write(File.join(directory, "event.yml"), <<~YAML)
      ---
      id: "#{id}"
      title: "#{title}"
      location: "#{location}"
      kind: "#{kind}"
      start_date: "#{start_date}"
      end_date: "#{end_date}"
    YAML
  end

  def with_events
    with_static_data_dir do |root|
      series_dir = File.join(root, "data/testconf")
      FileUtils.mkdir_p(series_dir)
      File.write(File.join(series_dir, "series.yml"), <<~YAML)
        ---
        id: "testconf"
        name: "TestConf"
        kind: "conference"
      YAML

      write_event(root, series_id: "testconf", id: "rubyconf-2024", title: "RubyConf 2024", kind: "conference", location: "San Diego, CA, United States", start_date: "2024-11-13", end_date: "2024-11-15")
      write_event(root, series_id: "testconf", id: "rubyconf-2025", title: "RubyConf 2025", kind: "conference", location: "San Diego, CA, United States", start_date: "2025-11-12", end_date: "2025-11-14")
      write_event(root, series_id: "testconf", id: "lrug-2026-01-12", title: "LRUG January 2026", kind: "meetup", location: "London, United Kingdom", start_date: "2026-01-12", end_date: "2026-01-12")
      write_event(root, series_id: "testconf", id: "baruco-2023", title: "Baruco 2023", kind: "conference", location: "Madrid, Spain", start_date: "2023-09-08", end_date: "2023-09-09")

      yield root
    end
  end

  test "returns all events when no arguments are given" do
    with_events do
      result = build_tool.execute

      assert_equal 4, result.size
    end
  end

  test "finds events by title query" do
    with_events do
      result = build_tool.execute(query: "RubyConf")

      assert_equal 2, result.size
      assert result.all? { |event| event[:title].include?("RubyConf") }
    end
  end

  test "finds events by slug query" do
    with_events do
      result = build_tool.execute(query: "lrug")

      assert_equal 1, result.size
      assert_equal "LRUG January 2026", result.first[:title]
    end
  end

  test "finds events by location query" do
    with_events do
      result = build_tool.execute(query: "Madrid")

      assert_equal 1, result.size
      assert_equal "Baruco 2023", result.first[:title]
    end
  end

  test "query is case insensitive" do
    with_events do
      result = build_tool.execute(query: "rubyconf")

      assert_equal 2, result.size
    end
  end

  test "filters by start_date, keeping events ending on or after it" do
    with_events do
      result = build_tool.execute(start_date: "2024-01-01")

      titles = result.map { |e| e[:title] }
      assert_equal 3, result.size
      assert titles.include?("RubyConf 2024")
      assert titles.include?("RubyConf 2025")
      assert titles.include?("LRUG January 2026")
      refute titles.include?("Baruco 2023")
    end
  end

  test "filters by end_date, keeping events starting on or before it" do
    with_events do
      result = build_tool.execute(end_date: "2024-12-31")

      titles = result.map { |e| e[:title] }
      assert_equal 2, result.size
      assert titles.include?("RubyConf 2024")
      assert titles.include?("Baruco 2023")
    end
  end

  test "uses overlap semantics when both dates are given" do
    with_events do
      result = build_tool.execute(start_date: "2024-01-01", end_date: "2024-12-31")

      assert_equal 1, result.size
      assert_equal "RubyConf 2024", result.first[:title]
    end
  end

  test "filters by kind" do
    with_events do
      result = build_tool.execute(kind: "meetup")

      assert_equal 1, result.size
      assert_equal "meetup", result.first[:kind]
      assert_equal "LRUG January 2026", result.first[:title]
    end
  end

  test "combines query, kind, and date filters" do
    with_events do
      result = build_tool.execute(query: "RubyConf", kind: "conference", start_date: "2025-01-01")

      assert_equal 1, result.size
      assert_equal "RubyConf 2025", result.first[:title]
    end
  end

  test "returns error for invalid kind" do
    with_events do
      result = build_tool.execute(kind: "festival")

      assert_equal({error: "Invalid kind 'festival'. Must be one of: event, conference, meetup, retreat, hackathon, workshop"}, result)
    end
  end

  test "unparseable start_date does not crash" do
    with_events do
      result = build_tool.execute(start_date: "not-a-date")

      assert_equal 4, result.size
    end
  end

  test "unparseable end_date does not crash" do
    with_events do
      result = build_tool.execute(end_date: "not-a-date")

      assert_equal 4, result.size
    end
  end
end
