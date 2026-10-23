# frozen_string_literal: true

require "test_helper"

class Static::MatchesPathValidatorTest < ActiveSupport::TestCase
  include StaticDataSandbox

  test "event and series ids that match their folders are valid" do
    assert_empty lint_errors(Static::Event.find_by_slug("helveticruby-2025"), :id)
    assert_empty lint_errors(Static::EventSeries.find_by_slug("helveticruby"), :id)
  end

  test "flags an event id that does not match the folder name" do
    with_record("testconf/testconf-2025/event.yml", %(id: "some-other-event"\ntitle: "TestConf"\nkind: "conference")) do |path|
      event = Static::Event.in_file(path).first

      assert_equal [%(id "some-other-event" does not match the folder name "testconf-2025")], lint_errors(event, :id)
      assert_equal 2, event.error_location(event.errors.where(:id).first).start_line
    end
  end

  test "flags a series id that does not match the folder name" do
    with_record("testconf/series.yml", %(id: "wrong-series"\nname: "TestConf")) do |path|
      series = Static::EventSeries.in_file(path).first

      assert_equal [%(id "wrong-series" does not match the folder name "testconf")], lint_errors(series, :id)
    end
  end

  test "flags a missing id" do
    with_record("testconf/testconf-2025/event.yml", %(title: "TestConf"\nkind: "conference")) do |path|
      event = Static::Event.in_file(path).first

      assert_equal [%(id is required and must match the folder name "testconf-2025")], lint_errors(event, :id)
    end
  end

  private

  def lint_errors(record, attribute)
    record.valid?(:lint)
    record.errors.full_messages_for(attribute)
  end

  def with_record(relative_path, yaml)
    with_static_data_dir do |root|
      path = File.join(root, "data", relative_path)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, "---\n#{yaml}\n")

      yield path
    end
  end
end
