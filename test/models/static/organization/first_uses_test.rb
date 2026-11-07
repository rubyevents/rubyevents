require "test_helper"

class Static::Organization::FirstUsesTest < ActiveSupport::TestCase
  include StaticDataSandbox

  setup do
    @base = Dir.mktmpdir("first_uses_base")
    @head = Dir.mktmpdir("first_uses_head")

    [@base, @head].each do |root|
      write_data_file(root, "data/alpha/series.yml", {"name" => "Alpha"})
      write_data_file(root, "data/beta/series.yml", {"name" => "Beta"})
      write_data_file(root, "data/alpha/alpha-2025/sponsors.yml", [{"tiers" => [{"name" => "Gold", "level" => 1, "sponsors" => [{"slug" => "appsignal"}]}]}])
      write_data_file(root, "data/beta/involvements.yml", [{"name" => "Organizer", "organizations" => ["typesense"]}])
    end

    organizations = [
      {"slug" => "appsignal", "name" => "AppSignal", "alternate_names" => ["Appsignal"], "website" => "https://www.appsignal.com"},
      {"slug" => "typesense", "name" => "Typesense", "aliases" => [{"name" => "TypeSense", "slug" => "type-sense"}]}
    ]
    write_data_file(@base, "data/organizations.yml", organizations)
    # The report shows the base's entry, the one to compare against, never text from the change
    write_data_file(@head, "data/organizations.yml", [organizations.first.merge("name" => "@someone")] + organizations.drop(1) + [{"slug" => "planet-argon", "name" => "Planet Argon"}])
  end

  teardown do
    FileUtils.rm_rf(@base)
    FileUtils.rm_rf(@head)
  end

  test "lists existing organizations a series references for the first time, per series and organization" do
    path = write_data_file(@head, "data/beta/beta-2026/sponsors.yml", [{"tiers" => [
      {"name" => "Gold", "level" => 1, "sponsors" => [{"slug" => "type-sense"}, {"slug" => "planet-argon"}, {"slug" => "appsignal"}]},
      {"name" => "Silver", "level" => 2, "sponsors" => [{"slug" => "appsignal"}]}
    ]}])
    write_data_file(@head, "data/alpha/involvements.yml", [{"name" => "Organizer", "organizations" => [{"slug" => "typesense", "from" => "2024"}]}])

    findings = Static::Organization::FirstUses.new(base_root: @base, head_root: @head).findings

    assert_equal [["data/alpha", "typesense"], ["data/beta", "appsignal"]], findings.map { |finding| [finding.series, finding.organization.slug] }

    appsignal = findings.last
    appsignal_lines = File.readlines(path).each_with_index.filter_map { |line, index| index + 1 if line.include?("appsignal") }
    assert_equal appsignal_lines, appsignal.references.map(&:line)
    assert_equal ["data/alpha"], appsignal.other_series
    assert_equal "AppSignal", appsignal.organization.name
  end

  test "reports per series, linking the new references" do
    path = write_data_file(@head, "data/beta/beta-2026/sponsors.yml", [{"tiers" => [{"name" => "Gold", "level" => 1, "sponsors" => [{"slug" => "appsignal"}]}]}])
    line = File.readlines(path).index { |text| text.include?("appsignal") } + 1

    report = Static::Organization::FirstUses.new(base_root: @base, head_root: @head).report(link: ->(file, number) { "https://example.com/#{file}#L#{number}" })

    assert_match "# New references detected", report
    assert_match "<summary><h2>By <code>data/beta</code></h2></summary>", report
    assert_match <<~MARKDOWN, report
      `appsignal`:
      - Names: AppSignal, Appsignal
      - Websites: https://www.appsignal.com
      - New references:
        - [beta-2026/sponsors.yml:#{line}](https://example.com/data/beta/beta-2026/sponsors.yml#L#{line})
      - Also referenced by 1 other series:
        - `data/alpha`
    MARKDOWN
    assert report.strip.end_with?(Static::Organization::FirstUses::MARKER)
  end

  test "only looks at the given files on the head side" do
    write_data_file(@head, "data/beta/beta-2026/sponsors.yml", [{"tiers" => [{"name" => "Gold", "level" => 1, "sponsors" => [{"slug" => "appsignal"}]}]}])

    first_uses = Static::Organization::FirstUses.new(base_root: @base, head_root: @head, paths: ["data/alpha/alpha-2025/sponsors.yml"])

    assert_empty first_uses.findings
    assert_nil first_uses.report
  end

  test "finds nothing while the base has no organizations.yml" do
    FileUtils.rm(File.join(@base, "data/organizations.yml"))
    write_data_file(@head, "data/beta/beta-2026/sponsors.yml", [{"tiers" => [{"name" => "Gold", "level" => 1, "sponsors" => [{"slug" => "appsignal"}]}]}])

    assert_empty Static::Organization::FirstUses.new(base_root: @base, head_root: @head).findings
  end
end
