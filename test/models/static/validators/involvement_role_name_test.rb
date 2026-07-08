# frozen_string_literal: true

require "test_helper"

class Static::Validators::InvolvementRoleNameTest < ActiveSupport::TestCase
  test "applicable? returns true for involvements.yml" do
    with_temp_involvements([{"name" => "Organizer"}]) do |path|
      assert Static::Validators::InvolvementRoleName.new(file_path: path).applicable?
    end
  end

  test "applicable? returns false for event.yml" do
    file = Dir.glob(Rails.root.join("data/**/event.yml")).first

    assert_not Static::Validators::InvolvementRoleName.new(file_path: file).applicable?
  end

  test "does not return errors for singular role names" do
    with_temp_involvements([
      {"name" => "Organizer"},
      {"name" => "Volunteer"}
    ]) do |path|
      assert_empty Static::Validators::InvolvementRoleName.new(file_path: path).errors
    end
  end

  test "returns an error for plural role names" do
    with_temp_involvements([
      {"name" => "Organizers"}
    ]) do |path|
      errors = Static::Validators::InvolvementRoleName.new(file_path: path).errors

      assert_equal 1, errors.size
      assert_match "should be singular", errors.first.message
    end
  end

  test "returns multiple errors for multiple plural role names" do
    with_temp_involvements([
      {"name" => "Organizers"},
      {"name" => "Volunteers"}
    ]) do |path|
      errors = Static::Validators::InvolvementRoleName.new(file_path: path).errors

      assert_equal 2, errors.size
    end
  end

  private

  def with_temp_involvements(involvements)
    dir = Dir.mktmpdir
    path = File.join(dir, "data", "rubyconf", "2025", "involvements.yml")

    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, involvements.to_yaml)

    yield path
  ensure
    FileUtils.rm_rf(dir)
  end
end
