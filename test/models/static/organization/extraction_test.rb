# frozen_string_literal: true

require "test_helper"

class Static::Organization::ExtractionTest < ActiveSupport::TestCase
  include StaticDataSandbox

  LOGO_A = "https://testconf.example/2024/shopify.png"
  LOGO_B = "https://testconf.example/2025/shopify.svg"
  LOGO_C = "https://testconf.example/2025/scout.png"
  LOGO_D = "https://testconf.example/2025/typesense.png"

  test "extracts organizations following production's grouping" do
    with_legacy_data do |dir|
      report = Static::Organization::Extraction.new(snapshot: snapshot, log: StringIO.new).run!

      organizations = Static::Organization.all
      assert_equal %w[ruby-central scoutapm shopify typesense], organizations.slugs
      assert_equal 4, report[:organizations_added]
      assert_equal({"scoutapm" => %w[scout-apm], "shopify" => %w[shopify-engineering]}, report[:merged_groups])
      assert_empty report[:fallback_groups]
      assert_equal({"Ruby Central" => "ruby-central", "Scout APM" => "scoutapm"}, report[:involvement_slugs])

      shopify = organizations.find_by(slug: "shopify")
      assert_equal "Shopify", shopify.name
      assert_equal [{"name" => "Shopify Engineering", "slug" => "shopify-engineering"}], shopify["aliases"]
      assert_nil shopify["alternate_names"]
      assert_equal "https://www.shopify.com", shopify.website
      assert_nil shopify["websites"], "variants that differ only by www/trailing slash collapse"
      assert_equal LOGO_A, shopify.logo_url
      assert_equal [LOGO_B], shopify["logo_urls"]
      assert_equal "black", shopify.logo_background
      assert_equal "Ottawa, Canada", shopify.main_location

      scoutapm = organizations.find_by(slug: "scoutapm")
      assert_equal "ScoutAPM", scoutapm.name
      assert_equal [{"name" => "Scout APM", "slug" => "scout-apm"}], scoutapm["aliases"]
      assert_equal "https://www.scoutapm.com/", scoutapm.website, "most recent spelling wins a tie"
      assert_equal LOGO_C, scoutapm.logo_url

      typesense = organizations.find_by(slug: "typesense")
      assert_equal "typesense", typesense.name, "production's name wins"
      assert_equal ["Typesense"], typesense["alternate_names"]
      assert_equal "https://typesense.org", typesense.website
      assert_equal "Search", typesense.description

      ruby_central = organizations.find_by(slug: "ruby-central")
      assert_equal "Ruby Central", ruby_central.name
      assert_nil ruby_central.website

      content = File.read(File.join(dir, "data/organizations.yml"))
      # The Yerbafile (quotes, blank lines) only applies under data/, so the sandbox file keeps plain scalars
      assert_match(/^- slug: shopify\n  # Merged from:\n  # - slug: "shopify"\n  #   name: "Shopify"\n  #   website: "https:\/\/www.shopify.com\/"\n  #   logo_url: "#{Regexp.escape(LOGO_A)}"\n  #   sources:\n  #     - "data\/testconf\/testconf-2024\/sponsors.yml"\n  # - slug: "shopify-engineering"/o, content)
      assert_match(/^- slug: scoutapm\n  # Merged from:\n  # - slug: "scoutapm"\n(  #.*\n)*  # - slug: "scout-apm"\n  #   name: "Scout APM"\n(  #.*\n)*  #   sources:\n  #     - "data\/testconf\/testconf-2025\/involvements.yml"\n  #     - "data\/testconf\/testconf-2025\/sponsors.yml"\n  aliases:/, content)
      assert_equal 2, content.scan("# Merged from:").size

      sponsors_2025 = Yerba.parse_file(File.join(dir, "data/testconf/testconf-2025/sponsors.yml"))
      assert_equal [{"slug" => "shopify"}, {"slug" => "scoutapm"}, {"slug" => "typesense"}], sponsors_2025.value_at("[0].tiers[0].sponsors")
      sponsors_2024 = Yerba.parse_file(File.join(dir, "data/testconf/testconf-2024/sponsors.yml"))
      assert_equal [{"slug" => "shopify"}, {"slug" => "scoutapm"}, {"slug" => "typesense", "badge" => "Coffee Sponsor"}], sponsors_2024.value_at("[0].tiers[0].sponsors")
      assert_match(/^# TODO: keep me$/, File.read(File.join(dir, "data/testconf/testconf-2024/sponsors.yml")), "comments in sponsors files survive")

      involvements = Yerba.parse_file(File.join(dir, "data/testconf/testconf-2025/involvements.yml"))
      assert_equal [{"name" => "Organizer", "users" => ["Jane Doe"], "organizations" => ["ruby-central", {"slug" => "scoutapm", "from" => "2024"}]}], involvements.to_a
      series_involvements = Yerba.parse_file(File.join(dir, "data/testconf/involvements.yml"))
      assert_equal [{"name" => "Organizer", "users" => ["Jane Doe"], "organizations" => []}], series_involvements.to_a

      assert_empty Static::Organization.all.missing_organizations
    end
  end

  test "a second run changes nothing" do
    with_legacy_data do |dir|
      Static::Organization::Extraction.new(snapshot: snapshot, log: StringIO.new).run!
      before = Dir.glob(File.join(dir, "data/**/*.yml")).sort.to_h { |path| [path, File.read(path)] }

      report = Static::Organization::Extraction.new(snapshot: snapshot, log: StringIO.new).run!

      assert_equal 0, report[:organizations_added]
      assert_equal 0, report[:rewritten_sponsor_files]
      assert_equal 0, report[:rewritten_involvement_files]
      assert_equal before, Dir.glob(File.join(dir, "data/**/*.yml")).sort.to_h { |path| [path, File.read(path)] }
    end
  end

  test "an alias added by hand rewrites the files that used the old slug" do
    with_legacy_data do |dir|
      Static::Organization::Extraction.new(snapshot: snapshot, log: StringIO.new).run!

      organizations = Static::Organization.all
      organizations.find_by(slug: "typesense").add_alias(name: "Typesense Search", slug: "typesense-search")
      organizations.save!
      write(dir, "data/testconf/testconf-2024/sponsors.yml", [{"tiers" => [{"name" => "Gold", "sponsors" => [{"slug" => "typesense-search"}, {"slug" => "typesense", "badge" => "Coffee Sponsor"}]}]}])
      StaticDataSandbox.models.each(&:unload!)

      report = Static::Organization::Extraction.new(snapshot: snapshot, log: StringIO.new).run!

      assert_equal 0, report[:organizations_added]
      assert_equal 1, report[:rewritten_sponsor_files]
      assert_equal [["data/testconf/testconf-2024/sponsors.yml", "typesense", "typesense"]], report[:deduplicated_sponsors]
      assert_equal [{"slug" => "typesense", "badge" => "Coffee Sponsor"}], Yerba.parse_file(File.join(dir, "data/testconf/testconf-2024/sponsors.yml")).value_at("[0].tiers[0].sponsors")
    end
  end

  test "an alias listed after its organization in the same tier is removed too" do
    with_legacy_data do |dir|
      Static::Organization::Extraction.new(snapshot: snapshot, log: StringIO.new).run!

      organizations = Static::Organization.all
      organizations.find_by(slug: "typesense").add_alias(name: "Typesense Search", slug: "typesense-search")
      organizations.save!
      write(dir, "data/testconf/testconf-2024/sponsors.yml", [{"tiers" => [{"name" => "Gold", "sponsors" => [{"slug" => "typesense"}, {"slug" => "typesense-search", "badge" => "Coffee Sponsor"}]}]}])
      StaticDataSandbox.models.each(&:unload!)

      report = Static::Organization::Extraction.new(snapshot: snapshot, log: StringIO.new).run!

      assert_equal 1, report[:rewritten_sponsor_files]
      assert_equal [{"slug" => "typesense", "badge" => "Coffee Sponsor"}], Yerba.parse_file(File.join(dir, "data/testconf/testconf-2024/sponsors.yml")).value_at("[0].tiers[0].sponsors")
    end
  end

  test "a slug production folded into an organization that is already in the file becomes its alias" do
    with_legacy_data do |dir|
      Static::Organization::Extraction.new(snapshot: snapshot, log: StringIO.new).run!
      write(dir, "data/testconf/testconf-2025/sponsors.yml", [{"tiers" => [{"name" => "Gold", "sponsors" => [{"slug" => "shopify-plus"}, {"slug" => "typesense"}]}]}])
      StaticDataSandbox.models.each(&:unload!)

      production = snapshot.to_h
      production["aliases"]["shopify-plus"] = "shopify"
      report = Static::Organization::Extraction.new(snapshot: Static::Organization::Snapshot.new(**production.symbolize_keys), log: StringIO.new).run!

      assert_equal 0, report[:organizations_added]
      assert_equal({"shopify" => %w[shopify-plus]}, report[:aliases_added])
      assert_equal 1, Static::Organization.all.count { |organization| organization.slug == "shopify" }
      assert_includes Static::Organization.find_by(slug: "shopify")["aliases"], {"name" => "Shopify Plus", "slug" => "shopify-plus"}
      assert_equal [{"slug" => "shopify"}, {"slug" => "typesense"}], Yerba.parse_file(File.join(dir, "data/testconf/testconf-2025/sponsors.yml")).value_at("[0].tiers[0].sponsors")
    end
  end

  test "without a snapshot, slugs are grouped by website domain and name, the shortest slug winning" do
    with_legacy_data do
      report = Static::Organization::Extraction.new(snapshot: nil, log: StringIO.new).run!

      assert_equal %w[ruby-central scoutapm shopify typesense], Static::Organization.all.slugs
      assert_equal %w[ruby-central scoutapm shopify typesense], report[:fallback_groups]
      assert_equal({"scoutapm" => %w[scout-apm], "shopify" => %w[shopify-engineering]}, report[:merged_groups])
      assert_equal "typesense", Static::Organization.find_by(slug: "typesense").name, "a tie in frequency goes to the most recent event"
      assert_equal "Shopify", Static::Organization.find_by(slug: "shopify").name
      assert_nil Static::Organization.find_by(slug: "shopify").main_location
    end
  end

  test "a slug production doesn't know joins the production organization that shares its domain" do
    with_legacy_data do |dir|
      write(dir, "data/testconf/testconf-2025/sponsors.yml", [{"tiers" => [{"name" => "Gold", "sponsors" => [
        {"name" => "Shopify Engineering", "slug" => "shopify-engineering", "website" => "https://shopify.com", "logo_url" => LOGO_B},
        {"name" => "Shopline", "slug" => "shopline", "website" => "https://bit.ly/shopline"},
        {"name" => "Cookpad", "slug" => "cookpad", "website" => "https://bit.ly/cookpad-jobs"}
      ]}]}])
      StaticDataSandbox.models.each(&:unload!)

      production = snapshot.to_h
      production["organizations"]["shopify"]["website"] = "https://bit.ly/shopifyatrubykaigi"
      report = Static::Organization::Extraction.new(snapshot: Static::Organization::Snapshot.new(**production.symbolize_keys), log: StringIO.new).run!

      assert_equal %w[cookpad shopify-engineering shopline], report[:merged_groups]["shopify"]
      assert_equal %w[Cookpad Shopline], Static::Organization.find_by(slug: "shopify").alias_names.sort - ["Shopify Engineering"]
    end
  end

  private

  def snapshot
    Static::Organization::Snapshot.new(
      organizations: {
        "shopify" => {"name" => "Shopify", "website" => "https://www.shopify.com", "logo_url" => LOGO_A, "logo_background" => "black", "main_location" => "Ottawa, Canada", "events" => %w[testconf-2024 testconf-2025]},
        "scoutapm" => {"name" => "ScoutAPM", "website" => nil, "logo_url" => nil, "logo_background" => "white", "events" => %w[testconf-2024 testconf-2025]},
        "typesense" => {"name" => "typesense", "website" => "https://typesense.org", "logo_url" => nil, "logo_background" => "white", "description" => "Search", "events" => %w[testconf-2024 testconf-2025]},
        "ruby-central" => {"name" => "Ruby Central", "website" => nil, "events" => []}
      },
      aliases: {},
      unknown: %w[shopify-engineering scout-apm],
      crawled_at: "2026-10-30T10:00:00Z",
      base_url: "https://www.rubyevents.org"
    )
  end

  def with_legacy_data
    with_static_data_dir do |dir|
      write(dir, "data/testconf/series.yml", {"id" => "testconf", "name" => "TestConf", "kind" => "conference"})
      write(dir, "data/testconf/testconf-2024/event.yml", {"id" => "testconf-2024", "title" => "TestConf 2024", "start_date" => "2024-05-01", "end_date" => "2024-05-02"})
      write(dir, "data/testconf/testconf-2025/event.yml", {"id" => "testconf-2025", "title" => "TestConf 2025", "start_date" => "2025-05-01", "end_date" => "2025-05-02"})
      write(dir, "data/testconf/testconf-2024/sponsors.yml", [{"tiers" => [{"name" => "Gold", "sponsors" => [
        {"name" => "Shopify", "slug" => "shopify", "website" => "https://www.shopify.com/", "logo_url" => LOGO_A},
        {"name" => "ScoutAPM", "slug" => "scoutapm", "website" => "https://scoutapm.com"},
        {"name" => "Typesense", "slug" => "typesense", "website" => "https://typesense.org", "badge" => "Coffee Sponsor"}
      ]}]}], comment: "# TODO: keep me")
      write(dir, "data/testconf/testconf-2025/sponsors.yml", [{"tiers" => [{"name" => "Gold", "sponsors" => [
        {"name" => "Shopify Engineering", "slug" => "shopify-engineering", "website" => "https://shopify.com", "logo_url" => LOGO_B},
        {"name" => "Scout APM", "slug" => "scout-apm", "website" => "https://www.scoutapm.com/", "logo_url" => LOGO_C},
        {"name" => "typesense", "slug" => "typesense", "website" => "https://typesense.org/", "logo_url" => LOGO_D}
      ]}]}])
      write(dir, "data/testconf/testconf-2025/involvements.yml", [{"name" => "Organizer", "users" => ["Jane Doe"], "organisations" => ["Ruby Central", {"name" => "Scout APM", "from" => "2024"}]}])
      write(dir, "data/testconf/involvements.yml", [{"name" => "Organizer", "users" => ["Jane Doe"], "organisations" => []}])

      yield dir
    end
  end

  def write(dir, path, content, comment: nil)
    full_path = File.join(dir, path)
    FileUtils.mkdir_p(File.dirname(full_path))
    File.write(full_path, [comment, Yerba::Document.from(content).to_s].compact.join("\n"))
  end
end
