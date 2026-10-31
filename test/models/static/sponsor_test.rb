require "test_helper"

class Static::SponsorTest < ActiveSupport::TestCase
  SPONSORS = <<~YAML
    ---
    - tiers:
        - name: "Gold"
          sponsors:
            - name: "Avo"
              slug: "avo"
              website: "https://avohq.io"

        - name: "Silver"
          sponsors:
            - name: "AppSignal"
              slug: "appsignal"
              website: "https://appsignal.com"

            - name: "Typesense"
              slug: "typesense"
              website: "https://typesense.org"
  YAML

  setup do
    @dir = Dir.mktmpdir
    @path = File.join(@dir, "sponsors.yml")
    File.write(@path, SPONSORS)
  end

  teardown do
    FileUtils.rm_rf(@dir)
  end

  def sponsors
    Static::Sponsor.in_file(@path)
  end

  test "tiers and their sponsors are nested records" do
    tier = sponsors.first.tiers.last
    entry = tier.sponsors.last

    assert_instance_of Static::Sponsor::Tier, tier
    assert_instance_of Static::Sponsor::Entry, entry
    assert_equal "Silver", tier["name"]
    assert_equal "typesense", entry["slug"]
    assert_equal tier, entry.parent
    assert_equal 16, entry.source_line("slug")
  end

  test "nested records of another model stay out of the model's collection" do
    assert_equal 1, sponsors.count
    assert_equal [Static::Sponsor], sponsors.map(&:class).uniq
  end

  test "a sponsor entry can be changed, removed and added" do
    tiers = sponsors.first.tiers
    tiers.last.sponsors.find_by(slug: "appsignal").tap { |entry| entry["slug"] = "app-signal" }.save!
    tiers.first.sponsors.find_by(slug: "avo").destroy
    tiers.first.sponsors.create(name: "Fly.io", slug: "fly-io", website: "https://fly.io")

    document = Yerba.parse_file(@path)

    assert_equal %w[fly-io], document.value_at("[0].tiers[0].sponsors[].slug")
    assert_equal %w[app-signal typesense], document.value_at("[0].tiers[1].sponsors[].slug")
  end
end
