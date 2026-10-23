# frozen_string_literal: true

require "test_helper"

class Static::InvolvementNameValidatorTest < ActiveSupport::TestCase
  test "allows singular role names" do
    assert_empty errors_for(<<~YAML)
      - name: Organizer
      - name: Volunteer
    YAML
  end

  test "flags a plural role name" do
    errors = errors_for(<<~YAML)
      - name: Volunteer
      - name: Organizers
    YAML

    assert_equal [[2, "'Organizers' should be singular"]], errors
  end

  test "flags every plural role name" do
    errors = errors_for(<<~YAML)
      - name: Organizers
      - name: Volunteers
    YAML

    assert_equal ["'Organizers' should be singular", "'Volunteers' should be singular"], errors.map(&:last)
  end

  test "allows a name together with users and organisations" do
    assert_empty errors_for(<<~YAML)
      - name: Organizer
        users:
          - Amanda Perino
        organisations:
          - Rails Foundation
    YAML
  end

  test "flags an involvement with neither a name nor organisations" do
    errors = errors_for(<<~YAML)
      - name: ""
    YAML

    assert_equal [[1, "name must be set when there are no organisations"]], errors
  end

  test "allows organisations without a name" do
    assert_empty errors_for(<<~YAML)
      - organisations:
          - rails
    YAML
  end

  private

  def errors_for(yaml)
    Dir.mktmpdir do |dir|
      path = File.join(dir, "data", "rubyconf", "2025", "involvements.yml")
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, yaml)

      Static::Involvement.in_file(path).flat_map do |involvement|
        involvement.valid?
        involvement.errors.map { |error| [involvement.error_location(error)&.start_line, error.full_message] }
      end
    end
  end
end
