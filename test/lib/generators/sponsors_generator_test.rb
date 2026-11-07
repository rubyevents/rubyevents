require "test_helper"
require "generators/sponsors/sponsors_generator"

class SponsorsGeneratorTest < Rails::Generators::TestCase
  include StaticOrganizationsSandbox

  tests SponsorsGenerator

  setup do
    self.class.destination Dir.mktmpdir("sponsors_generator", Rails.root.join("tmp").to_s)
    sandbox_organizations(
      {slug: "typesense", name: "Typesense", website: "https://typesense.org", aliases: [{"name" => "TypeSense", "slug" => "type-sense"}]},
      {slug: "appsignal", name: "AppSignal", alternate_names: ["AppSignal B.V."], website: "https://www.appsignal.com"},
      {slug: "planet-argon", name: "Planet Argon", website: "https://www.planetargon.com"},
      {slug: "honeybadger", name: "Honeybadger", website: "https://www.honeybadger.io"}
    )
  end

  teardown { FileUtils.remove_entry(destination_root) }

  test "generator creates an empty sponsors file with default tier" do
    file_path = File.join(destination_root, "data/tropicalrb/tropical-on-rails-2021/sponsors.yml")

    run_generator ["--event-series", "tropicalrb", "--event", "tropical-on-rails-2021"]

    assert_valid_file file_path do |content|
      assert_match(/name: "Sponsors"/, content)
    end
  end

  test "generator creates an empty sponsors file with specified tiers" do
    file_path = File.join(destination_root, "data/tropicalrb/tropical-on-rails-2022/sponsors.yml")

    run_generator ["--tiers", "Platinum,Gold,Silver", "--event-series", "tropicalrb", "--event", "tropical-on-rails-2022"]

    assert_valid_file file_path do |content|
      assert_match(/name: "Platinum"/, content)
      assert_match(/name: "Gold"/, content)
      assert_match(/name: "Silver"/, content)
    end
  end

  test "generator creates a whole sponsors file in one call, with the tiers in the order they appear" do
    file_path = File.join(destination_root, "data/tropicalrb/tropical-on-rails-2023/sponsors.yml")

    run_generator ["--event-series", "tropicalrb", "--event", "tropical-on-rails-2023",
      "--sponsors", "type-sense|Platinum", "AppSignal B.V.|Gold|Wifi Sponsor", "Planet Argon|Gold", "planet-argon|gold", "TypeSense|Platinum", "honeybadger"]

    assert_valid_file file_path do |content|
      assert_match(/name: "Platinum"\n\s+level: 0\n\s+sponsors:\n\s+- slug: "?typesense"?\n/, content)
      assert_match(/name: "Gold"\n\s+level: 1\n\s+sponsors:\n\s+- slug: "?appsignal"?\n\s+badge: "?Wifi Sponsor"?\n\s+- slug: "?planet-argon"?\n/, content)
      assert_match(/name: "Sponsors"\n\s+level: 2\n\s+sponsors:\n\s+- slug: "?honeybadger"?\n/, content)
      assert_equal 1, content.scan("planet-argon").size
      assert_equal 1, content.scan("typesense").size
    end

    assert_equal 4, Static::Organization.count
  end

  test "generator refuses organizations that aren't exactly a known slug or name, before writing anything" do
    error = capture(:stderr) do
      run_generator ["--event", "tropical-on-rails-2023", "--sponsors", "appsignal|Gold", "Appsignal|Gold", "Rubyists Inc.", "typsense|Gold"]
    end

    assert_match(/Not in .*: 'Appsignal', 'Rubyists Inc\.', 'typsense'\. .*bin\/rails g organization/, error)
    assert_no_file File.join(destination_root, "data/tropicalrb/tropical-on-rails-2023/sponsors.yml")
    assert_equal 4, Static::Organization.count
  end

  test "generator adds sponsors to an existing file and updates the ones already there" do
    file_path = File.join(destination_root, "data/tropicalrb/tropical-on-rails-2026/sponsors.yml")
    run_generator ["--tiers", "Platinum,Gold,Silver", "--event", "tropical-on-rails-2026", "--sponsors", "typesense|Gold|Wifi Sponsor"]

    run_generator ["--event", "tropical-on-rails-2026", "--sponsors", "typesense|Platinum", "appsignal|Silver"]
    run_generator ["--event", "tropical-on-rails-2026", "--sponsors", "appsignal||Coffee Sponsor"]

    assert_valid_file file_path do |content|
      assert_match(/name: "Platinum"\n\s+level: 0\n\s+sponsors:\n\s+- slug: "?typesense"?\n\s+badge: "?Wifi Sponsor"?/, content)
      assert_match(/name: "Silver"\n\s+level: 2\n\s+sponsors:\n\s+- slug: "?appsignal"?\n\s+badge: "?Coffee Sponsor"?/, content)
      assert_equal 1, content.scan("typesense").size
      assert_equal 1, content.scan("appsignal").size
    end
  end

  test "generator writes periods to a series' file, one entry per period" do
    file_path = File.join(destination_root, "data/tropicalrb/sponsors.yml")
    # The validators tell a series' file by the series.yml next to it
    FileUtils.mkdir_p(File.dirname(file_path))
    File.write(File.join(File.dirname(file_path), "series.yml"), "---\nname: \"Tropical.rb\"\n")

    run_generator ["--event-series", "tropicalrb", "--series-level", "--sponsors", "typesense|Sponsors||2019|2021", "typesense|Sponsors||2023"]
    run_generator ["--event-series", "tropicalrb", "--series-level", "--sponsors", "typesense|||2023-01|2024-06"]

    assert_valid_file file_path do |content|
      assert_match(/- slug: "?typesense"?\n\s+from: "2019"\n\s+to: "2021"\n/, content)
      assert_match(/- slug: "?typesense"?\n\s+from: "2023-01"\n\s+to: "2024-06"\n/, content)
      assert_equal 2, content.scan("typesense").size
    end
  end

  test "generator refuses periods in an event's file" do
    error = capture(:stderr) { run_generator ["--event-series", "tropicalrb", "--event", "tropical-on-rails-2024", "--sponsors", "typesense|Gold||2019"] }

    assert_match(/only a series' file takes/, error)
    assert_no_file File.join(destination_root, "data/tropicalrb/tropical-on-rails-2024/sponsors.yml")
  end

  def assert_valid_file(file_path, msg = nil, &block)
    errors = Static::Validators::Validator.sponsor_validator_classes.flat_map do |validator|
      validator.new(file_path:).errors
    end
    assert_empty errors, msg || errors.map { |e| e.to_h["message"] }.join(", ")
    assert_file file_path, msg, &block
  end
end
