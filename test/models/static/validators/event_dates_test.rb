# frozen_string_literal: true

require "test_helper"

class Static::Validators::EventDatesTest < ActiveSupport::TestCase
  VALID_EVENT_FILE = Rails.root.join("data/helveticruby/helveticruby-2025/event.yml").to_s

  test "applicable? returns true for an event.yml file" do
    validator = Static::Validators::EventDates.new(file_path: VALID_EVENT_FILE)
    assert validator.applicable?
  end

  test "applicable? returns false for a non-event.yml file" do
    file = Dir.glob(Rails.root.join("data/**/videos.yml")).first
    validator = Static::Validators::EventDates.new(file_path: file)
    assert_not validator.applicable?
  end

  test "applicable? returns false for a non-existent file" do
    validator = Static::Validators::EventDates.new(file_path: "/nonexistent/event.yml")
    assert_not validator.applicable?
  end

  test "returns empty errors for a valid conference event with dates" do
    validator = Static::Validators::EventDates.new(file_path: VALID_EVENT_FILE)
    assert_empty validator.errors
  end

  test "returns empty errors for a meetup event without dates" do
    yaml = {"name" => "My Meetup", "kind" => "meetup"}.to_yaml
    with_temp_event_yaml(yaml) do |path|
      validator = Static::Validators::EventDates.new(file_path: path)
      assert_empty validator.errors
    end
  end

  test "returns error when start_date is missing for non-meetup" do
    yaml = {"name" => "RubyConf", "kind" => "conference", "end_date" => "2025-11-15"}.to_yaml
    with_temp_event_yaml(yaml) do |path|
      validator = Static::Validators::EventDates.new(file_path: path)
      assert validator.errors.any? { |e| e.to_h["message"].include?("start_date") }
    end
  end

  test "returns error when end_date is missing for non-meetup" do
    yaml = {"name" => "RubyConf", "kind" => "conference", "start_date" => "2025-11-13"}.to_yaml
    with_temp_event_yaml(yaml) do |path|
      validator = Static::Validators::EventDates.new(file_path: path)
      assert validator.errors.any? { |e| e.to_h["message"].include?("end_date") }
    end
  end

  test "returns two errors when both dates are missing for non-meetup" do
    yaml = {"name" => "RubyConf", "kind" => "conference"}.to_yaml
    with_temp_event_yaml(yaml) do |path|
      validator = Static::Validators::EventDates.new(file_path: path)
      assert_equal 2, validator.errors.count
    end
  end

  test "errors are Static::Validators::Error objects" do
    yaml = {"name" => "RubyConf", "kind" => "conference"}.to_yaml
    with_temp_event_yaml(yaml) do |path|
      validator = Static::Validators::EventDates.new(file_path: path)
      assert validator.errors.all? { |e| e.is_a?(Static::Validators::Error) }
    end
  end

  private

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
