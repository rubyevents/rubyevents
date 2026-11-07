# frozen_string_literal: true

require "test_helper"

class Static::Validators::UniqueOrganizationReferencesTest < ActiveSupport::TestCase
  include StaticDataSandbox

  test "reports an organization listed twice in one tier, also through an alias" do
    with_file("sponsors.yml", [{"tiers" => [
      {"name" => "Gold", "sponsors" => [{"slug" => "appsignal"}, {"slug" => "typesense"}, {"slug" => "app-signal"}]},
      {"name" => "Silver", "sponsors" => [{"slug" => "appsignal"}]}
    ]}]) do |path|
      errors = Static::Validators::UniqueOrganizationReferences.new(file_path: path).errors

      assert_equal [%(Organization "appsignal" is listed 2 times in tier "Gold" (as "appsignal" and "app-signal"))], errors.map(&:message)
      assert_includes File.readlines(path)[errors.first.line - 1], "app-signal"
    end
  end

  test "in a series' file, different periods of the same sponsorship are allowed, the same start is not" do
    with_file("sponsors.yml", [{"tiers" => [{"name" => "Group", "sponsors" => [
      {"slug" => "appsignal", "from" => "2018", "to" => "2019"},
      {"slug" => "appsignal", "from" => "2022"},
      {"slug" => "typesense", "from" => "2022"},
      {"slug" => "typesense", "from" => "2022-01"}
    ]}]}], series: true) do |path|
      errors = Static::Validators::UniqueOrganizationReferences.new(file_path: path).errors

      assert_equal [%(Organization "typesense" is listed 2 times in tier "Group")], errors.map(&:message)
    end
  end

  test "an event's file has no periods, so dates don't separate entries" do
    with_file("sponsors.yml", [{"tiers" => [{"name" => "Gold", "sponsors" => [{"slug" => "appsignal", "from" => "2018"}, {"slug" => "appsignal", "from" => "2022"}]}]}]) do |path|
      errors = Static::Validators::UniqueOrganizationReferences.new(file_path: path).errors

      assert_equal [%(Organization "appsignal" is listed 2 times in tier "Gold")], errors.map(&:message)
    end
  end

  test "tiers and roles with the same name count as one, as in the import" do
    with_file("sponsors.yml", [{"tiers" => [
      {"name" => "Gold", "sponsors" => [{"slug" => "appsignal"}]},
      {"name" => "Gold", "sponsors" => [{"slug" => "app-signal"}]},
      {"sponsors" => [{"slug" => "typesense"}]},
      {"sponsors" => [{"slug" => "typesense"}]}
    ]}]) do |path|
      messages = Static::Validators::UniqueOrganizationReferences.new(file_path: path).errors.map(&:message)

      assert_equal [%(Organization "appsignal" is listed 2 times in tier "Gold" (as "appsignal" and "app-signal")), %(Organization "typesense" is listed 2 times in the unnamed tier)], messages
    end

    with_file("involvements.yml", [{"name" => "Organizer", "organizations" => ["typesense"]}, {"name" => "Organizer", "organizations" => [{"slug" => "typesense"}]}]) do |path|
      assert_equal 1, Static::Validators::UniqueOrganizationReferences.new(file_path: path).errors.size
    end
  end

  test "reports an organization listed twice in one role, not across roles" do
    with_file("involvements.yml", [
      {"name" => "Organizer", "organizations" => ["typesense", "typesense"]},
      {"name" => "Host", "organizations" => ["typesense"]}
    ]) do |path|
      errors = Static::Validators::UniqueOrganizationReferences.new(file_path: path).errors

      assert_equal [%(Organization "typesense" is listed 2 times in role "Organizer")], errors.map(&:message)
      assert_equal 5, errors.first.line
    end
  end

  test "applicable? only for sponsors.yml and involvements.yml" do
    with_file("sponsors.yml", [{"tiers" => []}]) do |path|
      assert Static::Validators::UniqueOrganizationReferences.new(file_path: path).applicable?
      assert_not Static::Validators::UniqueOrganizationReferences.new(file_path: path.sub("sponsors.yml", "event.yml")).applicable?
    end
  end

  private

  def with_file(name, content, series: false)
    with_static_data_dir do |dir|
      write_data_file(dir, "data/organizations.yml", [
        {"slug" => "appsignal", "aliases" => [{"name" => "App Signal", "slug" => "app-signal"}], "name" => "AppSignal"},
        {"slug" => "typesense", "name" => "Typesense"}
      ])
      write_data_file(dir, "data/testconf/testconf-2025/event.yml", {"id" => "testconf-2025", "title" => "TestConf 2025"})
      write_data_file(dir, "data/testconf/series.yml", {"id" => "testconf", "name" => "TestConf", "kind" => "meetup"}) if series
      folder = series ? "data/testconf" : "data/testconf/testconf-2025"

      yield write_data_file(dir, "#{folder}/#{name}", content)
    end
  end
end
