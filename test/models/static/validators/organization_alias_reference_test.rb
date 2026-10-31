# frozen_string_literal: true

require "test_helper"

class Static::Validators::OrganizationAliasReferenceTest < ActiveSupport::TestCase
  include StaticDataSandbox

  setup { Static::Validators::OrganizationAliasReference.reset! }
  teardown { Static::Validators::OrganizationAliasReference.reset! }

  test "reports references to an alias slug, with their line" do
    with_files do |files|
      errors = validator(files[:event_sponsors]).errors

      assert_equal [%(Organization slug "app-signal" is an alias of "appsignal"; use "appsignal" (bin/rails validate:fix updates it))], errors.map(&:message)
      assert_equal "app-signal", File.readlines(files[:event_sponsors])[errors.first.line - 1][/[\w-]+(?="?$)/]

      assert_equal 2, validator(files[:involvements]).errors.size
      assert_equal 1, validator(files[:series_sponsors]).errors.size
    end
  end

  test "current slugs and unknown slugs are not its business" do
    with_files do |files|
      File.write(files[:event_sponsors], Yerba::Document.from([{"tiers" => [{"name" => "Gold", "sponsors" => [{"slug" => "appsignal"}, {"slug" => "ghost-inc"}]}]}]).to_s)
      Static::Validators::OrganizationAliasReference.reset!

      assert_empty validator(files[:event_sponsors]).errors
    end
  end

  test "fix rewrites alias slugs and keeps everything else" do
    with_files do |files|
      result = validator(files[:involvements]).fix

      assert_equal 2, result[:changed]
      assert_equal [{"name" => "Organizer", "organizations" => ["appsignal", "appsignal", {"slug" => "appsignal", "from" => "2024"}]}], Yerba.parse_file(files[:involvements]).to_a
      assert_empty validator(files[:involvements]).errors

      validator(files[:event_sponsors]).fix
      assert_equal [{"slug" => "typesense"}, {"slug" => "appsignal", "badge" => "Coffee Sponsor"}], Yerba.parse_file(files[:event_sponsors]).value_at("[0].tiers[0].sponsors")
    end
  end

  test "a fix that lists an organization twice leaves that to the duplicate check" do
    with_files do |files|
      validator(files[:involvements]).fix

      errors = Static::Validators::UniqueOrganizationReferences.new(file_path: files[:involvements]).errors
      assert_equal [%(Organization "appsignal" is listed 3 times in role "Organizer")], errors.map(&:message)
    end
  end

  private

  def validator(path)
    Static::Validators::OrganizationAliasReference.new(file_path: path)
  end

  def with_files
    with_static_data_dir do |dir|
      write_data_file(dir, "data/organizations.yml", [
        {"slug" => "appsignal", "aliases" => [{"name" => "App Signal", "slug" => "app-signal"}], "name" => "AppSignal"},
        {"slug" => "typesense", "name" => "Typesense"}
      ])
      write_data_file(dir, "data/testrb/series.yml", {"id" => "testrb", "name" => "Test.rb", "kind" => "meetup"})
      files = {
        series_sponsors: write_data_file(dir, "data/testrb/sponsors.yml", [{"tiers" => [{"name" => "Group", "sponsors" => [{"slug" => "app-signal", "from" => "2024"}]}]}]),
        event_sponsors: write_data_file(dir, "data/testrb/testrb-2025-01/sponsors.yml", [{"tiers" => [{"name" => "Gold", "sponsors" => [{"slug" => "typesense"}, {"slug" => "app-signal", "badge" => "Coffee Sponsor"}]}]}]),
        involvements: write_data_file(dir, "data/testrb/testrb-2025-01/involvements.yml", [{"name" => "Organizer", "organizations" => ["app-signal", "appsignal", {"slug" => "app-signal", "from" => "2024"}]}])
      }
      write_data_file(dir, "data/testrb/testrb-2025-01/event.yml", {"id" => "testrb-2025-01", "title" => "Test.rb January 2025", "start_date" => "2025-01-15", "end_date" => "2025-01-15"})

      yield files
    end
  end
end
