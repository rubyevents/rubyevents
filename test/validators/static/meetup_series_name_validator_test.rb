# frozen_string_literal: true

require "test_helper"

class Static::MeetupSeriesNameValidatorTest < ActiveSupport::TestCase
  include StaticDataSandbox

  test "flags and strips a trailing Meetup" do
    with_series("Lyon.rb Meetup") do |series, path|
      assert_equal [%(name "Lyon.rb Meetup" ends in "Meetup", expected "Lyon.rb". The series is named after the group, and its meetups are titled "<name> Meetup <Month> <Year>". Run `bin/rails validate:fix` to rename it.)], name_errors(series)
      assert_equal 3, series.error_location(series.errors.where(:name).first).start_line

      Yerba::Record.fix_all([series], only: Static::MeetupSeriesNameValidator)
      assert_equal "Lyon.rb", Static::EventSeries.in_file(path).first["name"]
    end
  end

  test "ignores a series without a trailing Meetup" do
    with_series("Lyon.rb") do |series|
      assert_empty name_errors(series)
    end
  end

  test "accepts a trailing Meetup under a parent of the same name" do
    with_static_data_dir do |root|
      parent = File.join(root, "data", "testrb", "series.yml")
      child = File.join(root, "data", "testrb", "testrb-meetup", "series.yml")
      FileUtils.mkdir_p(File.dirname(child))
      File.write(parent, Yerba::Document.from({"id" => "testrb", "name" => "Test.rb", "kind" => "organisation"}).to_s)
      File.write(child, Yerba::Document.from({"id" => "testrb-meetup", "name" => "Test.rb Meetup", "kind" => "meetup"}).to_s)

      assert_empty name_errors(Static::EventSeries.in_file(child).first)
    end
  end

  test "ignores conference series" do
    with_series("Big Ruby Meetup", kind: "conference") do |series|
      assert_empty name_errors(series)
    end
  end

  private

  def name_errors(series)
    series.valid?(:lint)
    series.errors.full_messages_for(:name)
  end

  def with_series(name, kind: "meetup")
    with_static_data_dir do |root|
      path = File.join(root, "data", "testrb", "series.yml")
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, Yerba::Document.from({"id" => "testrb", "name" => name, "kind" => kind}).to_s)

      yield Static::EventSeries.in_file(path).first, path
    end
  end
end
