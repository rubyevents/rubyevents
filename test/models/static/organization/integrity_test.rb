# frozen_string_literal: true

require "test_helper"

class Static::Organization::IntegrityTest < ActiveSupport::TestCase
  include StaticDataSandbox

  test "missing, orphaned and duplicate candidates across sponsors and involvements" do
    with_data do
      organizations = Static::Organization.all

      assert_equal %w[scout-apm], organizations.missing_organizations
      assert_equal %w[honeybadger typesence], organizations.orphaned_organizations
      assert_equal Set["appsignal", "typesense", "scout-apm", "app-signal", "appsignal-bv"], organizations.all_referenced_slugs
      assert_equal({"https://www.appsignal.com" => 2}, organizations.duplicates(:website))

      candidate = organizations.duplicate_candidates.find { |entry| entry.slugs == %w[appsignal appsignal-bv] }
      assert_equal "share the domain appsignal.com", candidate.reason
      assert_includes organizations.duplicate_candidates.map(&:slugs), %w[typesence typesense]
    end
  end

  test "add_missing_organizations and remove_orphaned_organizations! sync the file" do
    with_data do
      organizations = Static::Organization.all

      assert_equal %w[scout-apm], organizations.add_missing_organizations
      assert_equal %w[honeybadger typesence], organizations.remove_orphaned_organizations!
      organizations.save!

      reloaded = Static::Organization.all
      assert_equal "Scout Apm", reloaded.find_by(slug: "scout-apm").name
      assert_empty reloaded.missing_organizations
      assert_empty reloaded.orphaned_organizations
    end
  end

  private

  def with_data
    with_static_data_dir do |dir|
      write(dir, "data/organizations.yml", [
        {"slug" => "appsignal", "name" => "AppSignal", "website" => "https://www.appsignal.com", "aliases" => [{"name" => "App Signal", "slug" => "app-signal"}]},
        {"slug" => "appsignal-bv", "name" => "AppSignal B.V.", "website" => "https://www.appsignal.com"},
        {"slug" => "honeybadger", "name" => "Honeybadger"},
        {"slug" => "typesense", "name" => "Typesense", "website" => "https://typesense.org"},
        {"slug" => "typesence", "name" => "Typesence", "website" => "https://bit.ly/typesence"}
      ])
      write(dir, "data/testconf/series.yml", {"id" => "testconf", "name" => "TestConf", "kind" => "conference"})
      write(dir, "data/testconf/testconf-2025/event.yml", {"id" => "testconf-2025", "title" => "TestConf 2025", "start_date" => "2025-05-01", "end_date" => "2025-05-02"})
      write(dir, "data/testconf/testconf-2025/sponsors.yml", [{"tiers" => [{"name" => "Gold", "sponsors" => [{"slug" => "appsignal"}, {"slug" => "scout-apm"}, {"slug" => "app-signal"}]}]}])
      write(dir, "data/testconf/testconf-2025/involvements.yml", [{"name" => "Organizer", "organizations" => ["typesense", {"slug" => "appsignal-bv", "from" => "2024"}]}])
      write(dir, "data/testconf/involvements.yml", [{"name" => "Sponsor", "organizations" => [{"slug" => "appsignal-bv", "from" => "2024"}]}])

      yield dir
    end
  end

  def write(dir, path, content)
    full_path = File.join(dir, path)
    FileUtils.mkdir_p(File.dirname(full_path))
    File.write(full_path, Yerba::Document.from(content).to_s)
  end
end
