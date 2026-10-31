# frozen_string_literal: true

require "test_helper"

class Static::OwnedImportsTest < ActiveSupport::TestCase
  include StaticDataSandbox

  test "sponsors and involvements resolve organizations by slug or alias slug" do
    with_event_files(sponsors: [{"slug" => "appsignal", "badge" => "Coffee Sponsor"}, {"slug" => "type-sense"}], involvements: [{"name" => "Organizer", "organizations" => ["appsignal"]}]) do |event|
      appsignal = Organization.create!(slug: "appsignal", name: "AppSignal")
      typesense = Organization.create!(slug: "typesense", name: "Typesense")
      typesense.aliases.create!(name: "Type Sense", slug: "type-sense")

      event.import_sponsors!(events(:railsconf_2017))
      event.import_involvements!(events(:railsconf_2017))

      sponsors = events(:railsconf_2017).sponsors
      assert_equal "Coffee Sponsor", sponsors.find_by(organization: appsignal).badge
      assert sponsors.exists?(organization: typesense)
      assert_equal [appsignal], events(:railsconf_2017).event_involvements.map(&:involvementable)
    end
  end

  test "an organization that is in organizations.yml but not yet in the database is imported on the way" do
    with_event_files(sponsors: [{"slug" => "honeybadger"}]) do |event|
      event.import_sponsors!(events(:railsconf_2017))

      organization = Organization.find_by!(slug: "honeybadger")
      assert_equal "Honeybadger", organization.name
      assert events(:railsconf_2017).sponsors.exists?(organization: organization)
    end
  end

  test "a slug that isn't in organizations.yml is an error" do
    with_event_files(sponsors: [{"slug" => "ghost-inc"}]) do |event|
      error = assert_raises(Static::Organization::MissingOrganizationError) { event.import_sponsors!(events(:railsconf_2017)) }

      assert_match(/Organization 'ghost-inc' referenced in .*sponsors.yml is not in data\/organizations.yml/, error.message)
    end
  end

  private

  def with_event_files(sponsors:, involvements: nil)
    with_static_data_dir do |dir|
      write(dir, "data/organizations.yml", [{"slug" => "honeybadger", "name" => "Honeybadger", "website" => "https://www.honeybadger.io"}])
      write(dir, "data/railsconf/series.yml", {"id" => "railsconf", "name" => "RailsConf", "kind" => "conference"})
      write(dir, "data/railsconf/railsconf-2017/event.yml", {"id" => "railsconf-2017", "title" => "RailsConf 2017", "start_date" => "2017-05-01", "end_date" => "2017-05-01"})
      write(dir, "data/railsconf/railsconf-2017/sponsors.yml", [{"tiers" => [{"name" => "Gold", "sponsors" => sponsors}]}])
      write(dir, "data/railsconf/railsconf-2017/involvements.yml", involvements) if involvements

      yield Static::Event.find_by_slug("railsconf-2017")
    end
  end

  def write(dir, path, content)
    full_path = File.join(dir, path)
    FileUtils.mkdir_p(File.dirname(full_path))
    File.write(full_path, Yerba::Document.from(content).to_s)
  end
end
