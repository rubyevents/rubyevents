# frozen_string_literal: true

require "test_helper"

class Static::Organization::SnapshotTest < ActiveSupport::TestCase
  INDEX_HTML = <<~HTML
    <a class="card" href="/organizations/appsignal"><img alt="AppSignal logo"></a>
    <a id="organization_1" class="flex" href="/organizations/appsignal">
      <img alt="AppSignal Logo" src="https://example.com/appsignal.svg"><span class="line-clamp-1">AppSignal</span>
    </a>
    <a id="organization_2" class="flex" href="/organizations/typesense">
      <img alt="typesense Logo" src="https://example.com/typesense.svg"><span class="line-clamp-1">typesense</span>
    </a>
  HTML

  ORGANIZATION_HTML = <<~HTML
    <html><head><link rel="stylesheet" href="https://rsms.me/inter/inter.css"></head><body>
    <div class="size-24 rounded-lg border p-2 md:size-36 bg-black">
      <img alt="AppSignal Logo" src="https://example.com/appsignal.svg">
    </div>
    <h1 class="font-bold text-black">AppSignal</h1>
    <h3 class="text-[#636B74]">Amsterdam, Netherlands</h3>
    <a href="https://www.appsignal.com" target="_blank" rel="noopener noreferrer">appsignal.com</a>
    <p class="mt-6 max-w-[700px] text-[#636B74]">
      Monitoring for Ruby apps
    </p>
    <a href="/events/rubyconf-2024">RubyConf 2024</a>
    <a href="/events/railsconf-2025/sponsors">RailsConf 2025</a>
    <a href="/events/rubyconf-2024">RubyConf 2024 again</a>
    <a href="https://www.rubyevents.org/organizations">Back</a>
    <footer><a target="_blank" href="https://status.rubyvideo.dev/">Status</a></footer>
    </body></html>
  HTML

  test "parse_index lists each organization once with slug and name" do
    assert_equal [["appsignal", "AppSignal"], ["typesense", "typesense"]], Static::Organization::Snapshot.parse_index(INDEX_HTML)
  end

  test "parse_organization reads the fields an organization page shows" do
    organization = Static::Organization::Snapshot.parse_organization(ORGANIZATION_HTML)

    assert_equal "AppSignal", organization["name"]
    assert_equal "https://www.appsignal.com", organization["website"]
    assert_equal "https://example.com/appsignal.svg", organization["logo_url"]
    assert_equal "black", organization["logo_background"]
    assert_equal "Amsterdam, Netherlands", organization["main_location"]
    assert_equal "Monitoring for Ruby apps", organization["description"]
    assert_equal %w[railsconf-2025 rubyconf-2024], organization["events"]
  end

  test "parse_organization leaves the website blank when the header has none" do
    organization = Static::Organization::Snapshot.parse_organization(ORGANIZATION_HTML.sub(%(<a href="https://www.appsignal.com" target="_blank" rel="noopener noreferrer">appsignal.com</a>), ""))

    assert_nil organization["website"]
  end

  test "parse_organization ignores local logo assets" do
    organization = Static::Organization::Snapshot.parse_organization(ORGANIZATION_HTML.sub("https://example.com/appsignal.svg", "/assets/organizations/appsignal/logo.webp"))

    assert_nil organization["logo_url"]
  end

  test "crawl visits the index, every organization and the slugs missing from the index" do
    pages = {
      "/organizations" => INDEX_HTML,
      "/organizations/appsignal" => ORGANIZATION_HTML,
      "/organizations/typesense" => ORGANIZATION_HTML.sub("AppSignal", "typesense"),
      "/organizations/app-signal" => ORGANIZATION_HTML
    }
    requested = []
    fetcher = lambda do |path|
      requested << path
      body = pages[path]
      Static::Organization::Snapshot::Page.new(status: body ? 200 : 301, body: body.to_s, location: body ? nil : "https://www.rubyevents.org/organizations")
    end

    snapshot = Static::Organization::Snapshot.crawl(slugs: %w[appsignal typesense app-signal jetbrains-s-r-o], fetcher: fetcher, delay: 0, log: StringIO.new)

    assert_equal ["/organizations", "/organizations/appsignal", "/organizations/typesense", "/organizations/app-signal", "/organizations/jetbrains-s-r-o"], requested
    assert_equal %w[appsignal typesense], snapshot.organizations.keys
    assert_equal "AppSignal", snapshot.organization("appsignal")["name"]
    assert_equal({"app-signal" => "appsignal"}, snapshot.aliases)
    assert_equal %w[jetbrains-s-r-o], snapshot.unknown
    assert snapshot.crawled_at.present?
  end

  test "write and load round-trip, and lookups" do
    snapshot = Static::Organization::Snapshot.new(
      organizations: {"appsignal" => {"name" => "AppSignal", "events" => %w[rubyconf-2024 railsconf-2025]}, "typesense" => {"name" => "typesense", "events" => %w[rubyconf-2024]}},
      aliases: {"app-signal" => "appsignal"},
      unknown: %w[jetbrains-s-r-o],
      crawled_at: "2026-10-30T10:00:00Z",
      base_url: "https://www.rubyevents.org"
    )

    Dir.mktmpdir do |dir|
      path = File.join(dir, "snapshot.json")
      snapshot.write(path)
      loaded = Static::Organization::Snapshot.load(path)

      assert_equal snapshot.to_h, loaded.to_h
      assert_equal "appsignal", loaded.canonical_slug("appsignal")
      assert_equal "appsignal", loaded.canonical_slug("app-signal")
      assert_nil loaded.canonical_slug("jetbrains-s-r-o")
      assert_equal "typesense", loaded.slug_by_name("Typesense")
      assert_equal %w[appsignal typesense], loaded.slugs_covering_events(%w[rubyconf-2024])
      assert_equal %w[appsignal], loaded.slugs_covering_events(%w[rubyconf-2024 railsconf-2025])
      assert_empty loaded.slugs_covering_events([])
    end

    assert_nil Static::Organization::Snapshot.load("/nonexistent/snapshot.json")
  end
end
