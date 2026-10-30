# frozen_string_literal: true

require "test_helper"

class Static::Validators::EventCityStateConsistencyTest < ActiveSupport::TestCase
  test "applicable? returns true for an event.yml file" do
    file = Dir.glob(Rails.root.join("data/**/event.yml")).first

    assert Static::Validators::EventCityStateConsistency.new(file_path: file).applicable?
  end

  test "applicable? returns false for a videos.yml file" do
    file = Dir.glob(Rails.root.join("data/**/videos.yml")).first

    assert_not Static::Validators::EventCityStateConsistency.new(file_path: file).applicable?
  end

  test "does not flag a city that consistently omits the state" do
    with_temp_events("testconf-2024" => "Sendai, Japan", "testconf-2025" => "Sendai, Japan") do |paths|
      assert_empty errors_for(paths)
    end
  end

  test "does not flag a city that consistently includes the state" do
    with_temp_events("testconf-2024" => "Sendai, Miyagi, Japan", "testconf-2025" => "Sendai, Miyagi, Japan") do |paths|
      assert_empty errors_for(paths)
    end
  end

  test "does not flag same-named cities in different states" do
    with_temp_events("testconf-2024" => "Portland, OR, United States", "testconf-2025" => "Portland, ME, United States") do |paths|
      assert_empty errors_for(paths)
    end
  end

  test "flags the event without a state when others in the city have one" do
    with_temp_events("testconf-2024" => "Sendai, Japan", "testconf-2025" => "Sendai, Miyagi, Japan") do |paths|
      errors = errors_for(paths)

      assert_equal 1, errors.size
      assert_includes errors.first.file_path, "testconf-2024/event.yml"
      assert_includes errors.first.message, %("Sendai, Japan" has no state)
      assert_includes errors.first.message, %("Sendai, Miyagi, Japan")
    end
  end

  private

  def errors_for(paths)
    Static::Validators::EventCityStateConsistency.inconsistency_errors(paths.flat_map { |path| Static::Event.in_file(path).to_a })
  end

  def with_temp_events(locations)
    dir = Dir.mktmpdir

    paths = locations.map do |event_slug, location|
      event_path = File.join(dir, "data", "testconf", event_slug, "event.yml")
      FileUtils.mkdir_p(File.dirname(event_path))
      File.write(event_path, <<~YAML)
        ---
        id: "#{event_slug}"
        title: "#{event_slug}"
        location: "#{location}"
      YAML
      event_path
    end

    yield paths
  ensure
    FileUtils.rm_rf(dir)
  end
end
