# frozen_string_literal: true

require "test_helper"

class Static::Validators::SponsorSlugTest < ActiveSupport::TestCase
  test "applicable? returns true for sponsors.yml" do
    with_temp_sponsors([{"name" => "Acme", "slug" => "acme", "website" => "https://acme.com"}]) do |path|
      assert Static::Validators::SponsorSlug.new(file_path: path).applicable?
    end
  end

  test "applicable? returns false for event.yml" do
    file = Dir.glob(Rails.root.join("data/**/event.yml")).first

    assert_not Static::Validators::SponsorSlug.new(file_path: file).applicable?
  end

  test "does not return errors when slug matches the parameterized name" do
    with_temp_sponsors([
      {"name" => "Acme Corp", "slug" => "acme-corp", "website" => "https://acme.com"},
      {"name" => "GitButler", "slug" => "gitbutler", "website" => "https://gitbutler.com"}
    ]) do |path|
      assert_empty Static::Validators::SponsorSlug.new(file_path: path).errors
    end
  end

  test "returns an error when slug does not match the parameterized name" do
    with_temp_sponsors([
      {"name" => "Acme Corp", "slug" => "acme", "website" => "https://acme.com"}
    ]) do |path|
      errors = Static::Validators::SponsorSlug.new(file_path: path).errors

      assert_equal 1, errors.size
      assert_match(/slug "acme" does not match the parameterized name "acme-corp"/, errors.first.message)
    end
  end

  test "returns multiple errors for multiple invalid slugs" do
    with_temp_sponsors([
      {"name" => "Acme Corp", "slug" => "acme", "website" => "https://acme.com"},
      {"name" => "Ruby Central", "slug" => "rubycentral", "website" => "https://rubycentral.org"}
    ]) do |path|
      errors = Static::Validators::SponsorSlug.new(file_path: path).errors

      assert_equal 2, errors.size
    end
  end

  test "parameterizes names with special characters" do
    with_temp_sponsors([
      {"name" => "Foo & Bar", "slug" => "foo-bar", "website" => "https://foo.bar"}
    ]) do |path|
      assert_empty Static::Validators::SponsorSlug.new(file_path: path).errors
    end
  end

  private

  def with_temp_sponsors(sponsors)
    dir = Dir.mktmpdir
    path = File.join(dir, "data", "rubyconf", "2025", "sponsors.yml")

    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, [{"tiers" => [{"name" => "Gold", "level" => 1, "sponsors" => sponsors}]}].to_yaml)

    yield path
  ensure
    FileUtils.rm_rf(dir)
  end
end
