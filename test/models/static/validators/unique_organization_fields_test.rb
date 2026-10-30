# frozen_string_literal: true

require "test_helper"

class Static::Validators::UniqueOrganizationFieldsTest < ActiveSupport::TestCase
  test "applicable? only for organizations.yml" do
    with_temp_organizations([{"slug" => "acme", "name" => "Acme"}]) do |path|
      assert Static::Validators::UniqueOrganizationFields.new(file_path: path).applicable?
    end

    assert_not Static::Validators::UniqueOrganizationFields.new(file_path: Dir.glob(Rails.root.join("data/**/event.yml")).first).applicable?
  end

  test "passes for unique slugs, names and aliases" do
    with_temp_organizations([
      {"slug" => "acme", "name" => "Acme", "aliases" => [{"name" => "ACME Corp", "slug" => "acme-corp"}]},
      {"slug" => "globex", "name" => "Globex"}
    ]) do |path|
      assert_empty Static::Validators::UniqueOrganizationFields.new(file_path: path).errors
    end
  end

  test "flags duplicate slugs and names" do
    with_temp_organizations([
      {"slug" => "acme", "name" => "Acme"},
      {"slug" => "acme", "name" => "Acme Inc"},
      {"slug" => "acme-2", "name" => "Acme"}
    ]) do |path|
      messages = Static::Validators::UniqueOrganizationFields.new(file_path: path).errors.map(&:message)

      assert_includes messages, "Duplicate slug: acme (2 occurrences)"
      assert_includes messages, "Duplicate name: Acme (2 occurrences)"
    end
  end

  test "flags alias slugs and names shared across organizations or taken by another organization" do
    with_temp_organizations([
      {"slug" => "acme", "name" => "Acme", "aliases" => [{"name" => "Globex", "slug" => "globex"}, {"name" => "Old Acme", "slug" => "old-acme"}]},
      {"slug" => "globex", "name" => "Globex"},
      {"slug" => "initech", "name" => "Initech", "aliases" => [{"name" => "Old Initech", "slug" => "old-acme"}]}
    ]) do |path|
      messages = Static::Validators::UniqueOrganizationFields.new(file_path: path).errors.map(&:message)

      assert_includes messages, "Alias slug 'globex' on acme conflicts with the slug of 'globex'"
      assert_includes messages, "Alias name 'Globex' on acme conflicts with the name of 'globex'"
      assert_includes messages, "Alias slug 'old-acme' shared across organizations: acme, initech"
    end
  end

  private

  def with_temp_organizations(organizations)
    dir = Dir.mktmpdir
    path = File.join(dir, "data", "organizations.yml")
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, Yerba::Document.from(organizations).to_s)

    yield path
  ensure
    FileUtils.rm_rf(dir)
  end
end
