# frozen_string_literal: true

require "test_helper"

class Static::OrganizationTest < ActiveSupport::TestCase
  include StaticOrganizationsSandbox

  setup do
    sandbox_organizations(
      {slug: "appsignal", name: "AppSignal", website: "https://www.appsignal.com", alternate_names: ["Appsignal"],
       aliases: [{"name" => "App Signal", "slug" => "app-signal"}], logo_url: "https://example.com/appsignal.svg", logo_urls: ["https://example.com/appsignal.png"]},
      {slug: "typesense", name: "Typesense", website: "https://typesense.org"}
    )
  end

  test "find_by slug, alias slug, name, alias name and alternate name" do
    assert_equal "AppSignal", Static::Organization.find_by(slug: "appsignal").name
    assert_equal "AppSignal", Static::Organization.find_by(slug: "app-signal").name
    assert_equal "appsignal", Static::Organization.find_by(name: "AppSignal").slug
    assert_equal "appsignal", Static::Organization.find_by(name: "App Signal").slug
    assert_equal "appsignal", Static::Organization.find_by(name: "Appsignal").slug
    assert_nil Static::Organization.find_by(slug: "nobody-#{SecureRandom.hex(4)}")
  end

  test "find_by falls back to a scan for non-indexed fields" do
    assert_equal "typesense", Static::Organization.find_by(website: "https://typesense.org").slug
  end

  test "known_slug? includes alias slugs" do
    assert Static::Organization.known_slug?("appsignal")
    assert Static::Organization.known_slug?("app-signal")
    assert_not Static::Organization.known_slug?("unknown")
  end

  test "add raises on blank and duplicate organizations" do
    assert_raises(Static::Organization::InvalidOrganizationError) { Static::Organization.add(slug: " ", name: "X") }
    assert_raises(Static::Organization::InvalidOrganizationError) { Static::Organization.add(slug: "x", name: " ") }
    assert_raises(Static::Organization::DuplicateOrganizationError) { Static::Organization.add(slug: "appsignal", name: "Other") }
    assert_raises(Static::Organization::DuplicateOrganizationError) { Static::Organization.add(slug: "app-signal", name: "Other") }
    assert_raises(Static::Organization::DuplicateOrganizationError) { Static::Organization.add(slug: "other", name: "AppSignal") }
  end

  test "add and save! write a new organization to the file in slug order" do
    Static::Organization.add(slug: "honeybadger", name: "Honeybadger", website: " https://www.honeybadger.io ", description: "")
    Static::Organization.save!

    reloaded = Static::Organization.find_by(slug: "honeybadger")
    assert_equal "https://www.honeybadger.io", reloaded.website
    assert_nil reloaded["description"]
    assert_equal %w[appsignal honeybadger typesense], Static::Organization.all.slugs
  end

  test "add_alias and add_alternate_name edit an organization" do
    organization = Static::Organization.find_by(slug: "typesense")
    organization.add_alias(name: "TypeSense Inc", slug: "typesense-inc")
    organization.add_alternate_name("TypeSense")
    organization.add_alternate_name("Typesense")
    organization.save!

    reloaded = Static::Organization.find_by(slug: "typesense-inc")
    assert_equal "typesense", reloaded.slug
    assert_equal ["TypeSense"], reloaded["alternate_names"]
    assert_equal ["Typesense", "TypeSense Inc", "TypeSense"], reloaded.all_names
  end

  test "rename_slug keeps the old slug as alias and rename keeps the old spelling" do
    organization = Static::Organization.find_by(slug: "typesense")

    organization.rename("Typesense Search")
    assert_equal ["Typesense"], organization["alternate_names"]

    organization.rename("Typesense")
    assert_equal ["Typesense Search"], organization["alternate_names"]

    organization.rename_slug("typesense-search")
    assert_equal [{"name" => "Typesense", "slug" => "typesense"}], organization["aliases"]

    organization.rename_slug("typesense")
    assert_equal [{"name" => "Typesense", "slug" => "typesense-search"}], organization["aliases"]
    assert_equal organization, organization.add_alias(name: "Again", slug: "typesense-search"), "adding an existing alias is a no-op"
    assert_equal 1, organization.alias_slugs.size
  end

  test "slug_for parameterizes like the organizations table" do
    assert_equal "planet-argon", Static::Organization.slug_for("Planet Argon")
    assert_equal "fjordbootcamp", Static::Organization.slug_for("FjordBootCamp")
    assert_equal "ruby", Static::Organization.slug_for("Ruby東海")
  end

  test "import! creates an organization with every field" do
    organization = Static::Organization.find_by(slug: "appsignal")
    organization.assign(kind: "company", main_location: "Amsterdam, Netherlands", logo_background: "black", description: "Monitoring")

    record = organization.import!(index: false)

    assert_equal "appsignal", record.slug
    assert_equal "AppSignal", record.name
    assert_equal "https://www.appsignal.com", record.website
    assert_equal "appsignal.com", record.domain
    assert_equal "company", record.kind
    assert_equal "Amsterdam, Netherlands", record.main_location
    assert_equal "black", record.logo_background
    assert_equal "https://example.com/appsignal.svg", record.logo_url
    assert_equal ["https://example.com/appsignal.svg", "https://example.com/appsignal.png"], record.logo_urls
    assert_equal "Monitoring", record.description
    assert_equal [["App Signal", "app-signal"]], record.aliases.pluck(:name, :slug)
    assert_equal record, Organization.find_by_slug_or_alias("app-signal")
  end

  test "import! syncs name, website and description but only fills blank admin fields" do
    existing = Organization.create!(slug: "appsignal", name: "Appsignal", kind: "community", main_location: "Utrecht", logo_background: "transparent",
      logo_url: "https://example.com/admin-pick.png", logo_urls: ["https://example.com/admin-pick.png"], website: "https://old.example.com")

    organization = Static::Organization.find_by(slug: "appsignal")
    organization.assign(kind: "company", main_location: "Amsterdam, Netherlands", logo_background: "black")
    organization.import!(index: false)

    existing.reload
    assert_equal "AppSignal", existing.name
    assert_equal "https://www.appsignal.com", existing.website
    assert_equal "community", existing.kind
    assert_equal "Utrecht", existing.main_location
    assert_equal "transparent", existing.logo_background
    assert_equal "https://example.com/admin-pick.png", existing.logo_url
    assert_equal ["https://example.com/admin-pick.png", "https://example.com/appsignal.svg", "https://example.com/appsignal.png"], existing.logo_urls
  end

  test "import! returns nil when nothing changed" do
    organization = Static::Organization.find_by(slug: "typesense")

    assert organization.import!(index: false)
    assert_nil organization.import!(index: false)
  end

  test "import! renames an organization found through an alias slug and keeps the old slug as alias" do
    existing = Organization.create!(slug: "app-signal", name: "App Signal")

    Static::Organization.find_by(slug: "appsignal").import!(index: false)

    existing.reload
    assert_equal "appsignal", existing.slug
    assert_equal "AppSignal", existing.name
    assert_equal existing, Organization.find_by_slug_or_alias("app-signal")
    assert_equal 1, Organization.where(slug: %w[appsignal app-signal]).count
  end

  test "import! keeps the old slug as alias when the YAML renamed the slug without listing it" do
    existing = Organization.create!(slug: "typesense-inc", name: "Typesense")
    organization = Static::Organization.find_by(slug: "typesense")
    organization.add_alias(name: "Typesense Inc", slug: "typesense-inc")

    organization.import!(index: false)

    assert_equal "typesense", existing.reload.slug
    assert_equal existing, Organization.find_by_slug_or_alias("typesense-inc")
  end

  test "import! merges a row that still exists under an alias slug, moving its sponsorships and involvements" do
    kept = Organization.create!(slug: "appsignal", name: "AppSignal")
    duplicate = Organization.create!(slug: "app-signal", name: "App Signal", logo_url: "https://example.com/old.png", logo_urls: ["https://example.com/old.png"])
    event = events(:railsconf_2017)
    other_event = events(:rails_world_2023)
    moved = Sponsor.create!(event: event, organization: duplicate, tier: "Gold")
    Sponsor.create!(event: other_event, organization: duplicate, tier: "Gold")
    Sponsor.create!(event: other_event, organization: kept, tier: "Gold")
    involvement = EventInvolvement.create!(event: event, involvementable: duplicate, role: "Organizer")

    Static::Organization.find_by(slug: "appsignal").import!(index: false)

    assert_nil Organization.find_by(id: duplicate.id)
    assert_equal kept, moved.reload.organization
    assert_equal 1, kept.sponsors.where(event: other_event).count
    assert_equal kept, involvement.reload.involvementable
    assert_includes kept.reload.logo_urls, "https://example.com/old.png"
    assert_equal kept, Organization.find_by_slug_or_alias("app-signal")
  end

  test "import_all! imports every organization once" do
    imported = Static::Organization.import_all!(index: false)

    assert_equal %w[appsignal typesense], imported.map(&:slug).sort
    assert_empty Static::Organization.import_all!(index: false)
  end

  test "with_path points the model at another file temporarily" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "organizations.yml")
      File.write(path, %(---\n- slug: "only-org"\n  name: "Only Org"\n))

      Static::Organization.with_path(path) do
        assert_equal ["only-org"], Static::Organization.all.slugs
      end

      assert_equal 2, Static::Organization.count
    end
  end
end
