# frozen_string_literal: true

require "test_helper"

class Static::Validators::EventDatePrecisionTest < ActiveSupport::TestCase
  test "applicable? returns false for a non-event.yml file" do
    file = Dir.glob(Rails.root.join("data/**/videos.yml")).first
    validator = Static::Validators::EventDatePrecision.new(file_path: file)
    assert_not validator.applicable?
  end

  test "returns empty errors when date_precision is day" do
    with_temp_event_yaml(event_yaml("day", "2027-03-14", "2027-03-15")) do |path|
      assert_empty Static::Validators::EventDatePrecision.new(file_path: path).errors
    end
  end

  test "returns empty errors when date_precision is missing" do
    yaml = <<~YAML
      ---
      name: "RubyConf"
      kind: "conference"
      start_date: "2027-03-14"
      end_date: "2027-03-15"
    YAML

    with_temp_event_yaml(yaml) do |path|
      assert_empty Static::Validators::EventDatePrecision.new(file_path: path).errors
    end
  end

  test "returns empty errors for year precision on the last day of the year" do
    with_temp_event_yaml(event_yaml("year", "2027-12-31", "2027-12-31")) do |path|
      assert_empty Static::Validators::EventDatePrecision.new(file_path: path).errors
    end
  end

  test "returns empty errors for month precision on the last day of the month" do
    with_temp_event_yaml(event_yaml("month", "2028-02-29", "2028-02-29")) do |path|
      assert_empty Static::Validators::EventDatePrecision.new(file_path: path).errors
    end
  end

  test "returns errors for year precision not on the last day of the year" do
    with_temp_event_yaml(event_yaml("year", "2027-01-01", "2027-01-01")) do |path|
      errors = Static::Validators::EventDatePrecision.new(file_path: path).errors

      assert_equal 2, errors.count
      assert errors.any? { |e| e.message.include?("start_date") && e.message.include?("2027-12-31") }
      assert errors.any? { |e| e.message.include?("end_date") && e.message.include?("2027-12-31") }
    end
  end

  test "returns errors for month precision not on the last day of the month" do
    with_temp_event_yaml(event_yaml("month", "2027-10-01", "2027-10-31")) do |path|
      errors = Static::Validators::EventDatePrecision.new(file_path: path).errors

      assert_equal 1, errors.count
      assert_includes errors.first.message, "start_date"
      assert_includes errors.first.message, "2027-10-31"
    end
  end

  test "fix moves the dates to the last day of the period" do
    with_temp_event_yaml(event_yaml("year", "2027-01-01", "2027-01-01")) do |path|
      result = Static::Validators::EventDatePrecision.new(file_path: path).fix

      assert_equal 2, result[:changed]
      assert_empty Static::Validators::EventDatePrecision.new(file_path: path).errors
      assert_includes File.read(path), %(start_date: "2027-12-31")
      assert_includes File.read(path), %(end_date: "2027-12-31")
    end
  end

  private

  def event_yaml(precision, start_date, end_date)
    <<~YAML
      ---
      name: "RubyConf"
      kind: "conference"
      date_precision: "#{precision}"
      start_date: "#{start_date}"
      end_date: "#{end_date}"
    YAML
  end

  def with_temp_event_yaml(yaml_content)
    dir = Dir.mktmpdir
    path = File.join(dir, "data", "testconf", "2025", "event.yml")
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, yaml_content)
    yield path
  ensure
    FileUtils.rm_rf(dir)
  end
end
