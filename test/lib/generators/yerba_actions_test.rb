require "test_helper"
require "generators/yerba_actions"

class YerbaActionsTest < ActiveSupport::TestCase
  class DummyGenerator < Rails::Generators::Base
    include Generators::YerbaActions
  end

  setup do
    @destination = Rails.root.join("tmp/generators/yerba_actions").to_s
    FileUtils.rm_rf(@destination)
    FileUtils.mkdir_p(@destination)
    @file = File.join(@destination, "sample.yml")
  end

  teardown do
    FileUtils.rm_rf(@destination)
  end

  def generator(behavior: :invoke, pretend: false)
    DummyGenerator.new([], {quiet: true, pretend: pretend}, {behavior: behavior, destination_root: @destination})
  end

  test "yaml_file creates a file and destroy removes it" do
    generator.yaml_file(@file, {"name" => "Test", "tags" => ["a", "b"]})

    assert File.exist?(@file)
    assert_match(/tags:\n  - a\n  - b/, File.read(@file))

    generator(behavior: :revoke).yaml_file(@file, {"name" => "Test", "tags" => ["a", "b"]})

    refute File.exist?(@file)
  end

  test "yaml_upsert appends, updates, and destroy removes again" do
    File.write(@file, "---\n[]\n")

    generator.yaml_upsert(@file, {"name" => "Organizer", "users" => ["Jim"]}, unique_by: {name: "Organizer"})
    assert_match(/- Jim/, File.read(@file))

    generator.yaml_upsert(@file, {"name" => "Organizer", "users" => ["Alice"]}, unique_by: {name: "Organizer"})
    content = File.read(@file)
    assert_match(/- Alice/, content)
    refute_match(/- Jim/, content)

    generator(behavior: :revoke).yaml_upsert(@file, {"name" => "Organizer", "users" => ["Alice"]}, unique_by: {name: "Organizer"})
    refute_match(/Organizer/, File.read(@file))
  end

  test "yaml_upsert with a selector targets a nested sequence" do
    File.write(@file, "tiers:\n  - name: \"Gold\"\n    sponsors: []\n")

    generator.yaml_upsert(@file, {"name" => "Acme"}, unique_by: {name: "Acme"}, selector: "tiers[0].sponsors")

    assert_match(/sponsors:\n      - name: Acme/, File.read(@file))

    generator(behavior: :revoke).yaml_upsert(@file, {"name" => "Acme"}, unique_by: {name: "Acme"}, selector: "tiers[0].sponsors")

    refute_match(/Acme/, File.read(@file))
  end

  test "yaml_insert adds a key and destroy round-trips byte-identically" do
    original = "name: \"Ruby\"\nyear: 1995\n"
    File.write(@file, original)

    generator.yaml_insert(@file, "website", "https://ruby-lang.org", after: "name")

    assert_equal "name: \"Ruby\"\nwebsite: https://ruby-lang.org\nyear: 1995\n", File.read(@file)

    generator(behavior: :revoke).yaml_insert(@file, "website", "https://ruby-lang.org", after: "name")

    assert_equal original, File.read(@file)
  end

  test "yaml_append adds a scalar and destroy removes it by value" do
    original = "tags:\n  - existing\n"
    File.write(@file, original)

    generator.yaml_append(@file, "added", selector: "tags")
    assert_match(/- added/, File.read(@file))

    generator(behavior: :revoke).yaml_append(@file, "added", selector: "tags")
    assert_equal original, File.read(@file)
  end

  test "yaml_append adds a hash and destroy removes it by full match" do
    File.write(@file, "---\n[]\n")
    item = {"name" => "Alice", "role" => "MC"}

    generator.yaml_append(@file, item)
    assert_match(/name: Alice/, File.read(@file))

    generator(behavior: :revoke).yaml_append(@file, item)
    refute_match(/Alice/, File.read(@file))
  end

  test "yaml_rename renames a key and destroy renames it back" do
    original = "name: \"Ruby\"\nyear: 1995\n"
    File.write(@file, original)

    generator.yaml_rename(@file, "year", "founded")
    assert_match(/founded: 1995/, File.read(@file))

    generator(behavior: :revoke).yaml_rename(@file, "year", "founded")
    assert_equal original, File.read(@file)
  end

  test "yaml_rename renames a nested key in place and destroy renames it back" do
    original = "details:\n  year: 1995\n  name: Ruby\n"
    File.write(@file, original)

    generator.yaml_rename(@file, "details.year", "founded")

    assert_equal "details:\n  founded: 1995\n  name: Ruby\n", File.read(@file)

    generator(behavior: :revoke).yaml_rename(@file, "details.year", "founded")

    assert_equal original, File.read(@file)
  end

  test "yaml_set overwrites a value and is a no-op on destroy" do
    File.write(@file, "coordinates:\n  latitude: 0.0\n")

    generator.yaml_set(@file, "coordinates.latitude", 47.37)
    assert_match(/latitude: 47.37/, File.read(@file))

    generator(behavior: :revoke).yaml_set(@file, "coordinates.latitude", 99.99)
    assert_match(/latitude: 47.37/, File.read(@file))
  end

  test "yaml_remove deletes a node and is a no-op on destroy" do
    File.write(@file, "name: \"Ruby\"\nyear: 1995\n")

    generator(behavior: :revoke).yaml_remove(@file, "year")
    assert_match(/year/, File.read(@file))

    generator.yaml_remove(@file, "year")
    refute_match(/year/, File.read(@file))
  end

  test "yaml_sort orders sequence items by a field" do
    File.write(@file, "items:\n  - name: b\n  - name: a\n")

    generator.yaml_sort(@file, "items", by: "name")

    assert_match(/items:\n  - name: a\n  - name: b/, File.read(@file))
  end

  test "yaml_sort_keys reorders map keys" do
    File.write(@file, "b: 1\na: 2\n")

    generator.yaml_sort_keys(@file, ["a", "b"])

    assert_match(/\Aa: 2\nb: 1\n/, File.read(@file))
  end

  test "pretend skips the write" do
    original = "name: \"Ruby\"\n"
    File.write(@file, original)

    generator(pretend: true).yaml_set(@file, "name", "Changed")
    generator(pretend: true).yaml_insert(@file, "website", "https://ruby-lang.org")

    assert_equal original, File.read(@file)

    sequence_file = File.join(@destination, "sequence.yml")
    File.write(sequence_file, "---\n[]\n")

    generator(pretend: true).yaml_upsert(sequence_file, {"name" => "x"}, unique_by: {name: "x"})
    generator(pretend: true).yaml_append(sequence_file, {"name" => "y"})

    assert_equal "---\n[]\n", File.read(sequence_file)
  end
end
