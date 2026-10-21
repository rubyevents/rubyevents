# frozen_string_literal: true

require "test_helper"

class Static::DatePrecisionValidatorTest < ActiveSupport::TestCase
  include StaticDataSandbox

  test "accepts any dates with day precision" do
    with_event("day", "2027-03-14", "2027-03-15") { |event| assert event.valid? }
  end

  test "accepts any dates without a date_precision" do
    with_event(nil, "2027-03-14", "2027-03-15") { |event| assert event.valid? }
  end

  test "accepts year precision on the last day of the year" do
    with_event("year", "2027-12-31", "2027-12-31") { |event| assert event.valid? }
  end

  test "accepts month precision on the last day of the month" do
    with_event("month", "2028-02-29", "2028-02-29") { |event| assert event.valid? }
  end

  test "flags year precision dates that are not the last day of the year" do
    with_event("year", "2027-01-01", "2027-01-01") do |event|
      assert_not event.valid?
      assert_equal [
        %(start_date (2027-01-01) must be the last day of the year (2027-12-31) when date_precision is "year". Run `bin/rails validate:fix` to update it.),
        %(end_date (2027-01-01) must be the last day of the year (2027-12-31) when date_precision is "year". Run `bin/rails validate:fix` to update it.)
      ], event.errors.full_messages
    end
  end

  test "flags month precision dates that are not the last day of the month" do
    with_event("month", "2027-10-01", "2027-10-31") do |event|
      assert_not event.valid?
      assert_equal [%(start_date (2027-10-01) must be the last day of the month (2027-10-31) when date_precision is "month". Run `bin/rails validate:fix` to update it.)], event.errors.full_messages
      assert_equal 5, event.error_location(event.errors.first).start_line
    end
  end

  test "fix moves the dates to the last day of the period" do
    with_event("year", "2027-01-01", "2027-01-01") do |event|
      fixes = Yerba::Record.fix_all([event], only: Static::DatePrecisionValidator)

      assert_equal [2], fixes.map(&:last)
      assert_includes File.read(event.file_path), %(start_date: "2027-12-31")
      assert_includes File.read(event.file_path), %(end_date: "2027-12-31")
      assert Static::Event.in_file(event.file_path).first.valid?
    end
  end

  private

  def with_event(precision, start_date, end_date)
    with_static_data_dir do |root|
      path = File.join(root, "data", "testconf", "testconf-2027", "event.yml")
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, <<~YAML)
        ---
        id: "testconf-2027"
        title: "TestConf"
        kind: "conference"
        start_date: "#{start_date}"
        end_date: "#{end_date}"
        #{%(date_precision: "#{precision}") if precision}
      YAML

      yield Static::Event.in_file(path).first
    end
  end
end
