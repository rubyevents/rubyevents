# frozen_string_literal: true

require "test_helper"

class Static::Validators::OrganizationExistsTest < ActiveSupport::TestCase
  include StaticDataSandbox

  setup do
    Static::Validators::OrganizationExists.reset!
  end

  teardown do
    Static::Validators::OrganizationExists.reset!
  end

  test "applicable? for sponsors.yml and involvements.yml, not for event.yml" do
    with_files do |sponsors_path, involvements_path, event_path|
      assert Static::Validators::OrganizationExists.new(file_path: sponsors_path).applicable?
      assert Static::Validators::OrganizationExists.new(file_path: involvements_path).applicable?
      assert_not Static::Validators::OrganizationExists.new(file_path: event_path).applicable?
      assert_not Static::Validators::OrganizationExists.new(file_path: "/nonexistent/sponsors.yml").applicable?
    end
  end

  test "returns an error per unknown slug, with the line of the reference" do
    with_files do |sponsors_path, involvements_path|
      sponsor_errors = Static::Validators::OrganizationExists.new(file_path: sponsors_path).errors
      assert_equal [%(Organization "ghost-inc" not found in data/organizations.yml)], sponsor_errors.map(&:message)
      assert_equal "ghost-inc", File.readlines(sponsors_path)[sponsor_errors.first.line - 1][/[\w-]+$/]

      involvement_errors = Static::Validators::OrganizationExists.new(file_path: involvements_path).errors
      assert_equal [%(Organization "phantom-org" not found in data/organizations.yml)], involvement_errors.map(&:message)
    end
  end

  test "fix adds the missing organizations, named after their slug" do
    with_files do |sponsors_path|
      result = Static::Validators::OrganizationExists.new(file_path: sponsors_path).fix

      assert_equal 2, result[:changed]
      assert_equal "Ghost Inc", Static::Organization.find_by(slug: "ghost-inc").name
      assert_equal "Phantom Org", Static::Organization.find_by(slug: "phantom-org").name
      assert_empty Static::Validators::OrganizationExists.new(file_path: sponsors_path).errors
    end
  end

  private

  def with_files
    with_static_data_dir do |dir|
      write(dir, "data/organizations.yml", [{"slug" => "appsignal", "name" => "AppSignal", "aliases" => [{"name" => "App Signal", "slug" => "app-signal"}]}])
      write(dir, "data/testconf/series.yml", {"id" => "testconf", "name" => "TestConf", "kind" => "conference"})
      write(dir, "data/testconf/testconf-2025/event.yml", {"id" => "testconf-2025", "title" => "TestConf 2025", "start_date" => "2025-05-01", "end_date" => "2025-05-02"})
      sponsors_path = write(dir, "data/testconf/testconf-2025/sponsors.yml", [{"tiers" => [{"name" => "Gold", "sponsors" => [{"slug" => "appsignal"}, {"slug" => "app-signal"}, {"slug" => "ghost-inc"}]}]}])
      involvements_path = write(dir, "data/testconf/testconf-2025/involvements.yml", [{"name" => "Organizer", "organizations" => ["appsignal", {"slug" => "phantom-org", "from" => "2024"}]}])

      yield sponsors_path, involvements_path, File.join(dir, "data/testconf/testconf-2025/event.yml")
    end
  end

  def write(dir, path, content)
    full_path = File.join(dir, path)
    FileUtils.mkdir_p(File.dirname(full_path))
    File.write(full_path, Yerba::Document.from(content).to_s)
    full_path
  end
end
