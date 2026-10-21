# frozen_string_literal: true

require "test_helper"

class Static::CityStateConsistencyValidatorTest < ActiveSupport::TestCase
  include StaticDataSandbox

  test "does not flag a city that consistently omits the state" do
    assert_empty location_errors("testconf-2024" => "Sendai, Japan", "testconf-2025" => "Sendai, Japan").values.flatten
  end

  test "does not flag a city that consistently includes the state" do
    assert_empty location_errors("testconf-2024" => "Sendai, Miyagi, Japan", "testconf-2025" => "Sendai, Miyagi, Japan").values.flatten
  end

  test "does not flag same-named cities in different states" do
    assert_empty location_errors("testconf-2024" => "Portland, OR, United States", "testconf-2025" => "Portland, ME, United States").values.flatten
  end

  test "flags the event without a state when others in the city have one" do
    errors = location_errors("testconf-2024" => "Sendai, Japan", "testconf-2025" => "Sendai, Miyagi, Japan")

    assert_equal [%(location "Sendai, Japan" has no state, but other events in this city use "Sendai, Miyagi, Japan". Mixed formats keep events off the city page.)], errors["testconf-2024"]
    assert_empty errors["testconf-2025"]
  end

  private

  def location_errors(locations)
    with_static_data_dir do |root|
      locations.each do |slug, location|
        path = File.join(root, "data", "testconf", slug, "event.yml")
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, <<~YAML)
          ---
          id: "#{slug}"
          title: "#{slug}"
          location: "#{location}"
        YAML
      end

      Static::Event.all.to_h do |event|
        event.valid?(:lint)
        [event.id, event.errors.full_messages_for(:location)]
      end
    end
  end
end
