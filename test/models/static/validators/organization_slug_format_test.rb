# frozen_string_literal: true

require "test_helper"

class Static::Validators::OrganizationSlugFormatTest < ActiveSupport::TestCase
  test "passes for lowercase slugs with digits and dashes" do
    with_temp_organizations([
      {"slug" => "acme-2", "name" => "Acme", "aliases" => [{"name" => "ACME", "slug" => "acme"}]},
      {"slug" => "10gen", "name" => "10gen"},
      {"slug" => "local_tech", "name" => "#local_tech"}
    ]) do |path|
      assert_empty Static::Validators::OrganizationSlugFormat.new(file_path: path).errors
    end
  end

  test "flags uppercase, spaces and other characters in slugs and alias slugs" do
    with_temp_organizations([
      {"slug" => "Acme Corp", "name" => "Acme", "aliases" => [{"name" => "ACME", "slug" => "acme.corp"}]},
      {"slug" => "globex-", "name" => "Globex"}
    ]) do |path|
      errors = Static::Validators::OrganizationSlugFormat.new(file_path: path).errors

      assert_equal 3, errors.size
      assert_match(/slug "Acme Corp" must consist of lowercase letters, digits, dashes and underscores, like "acme-corp"/, errors.first.message)
      assert_equal 2, errors.first.line
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
