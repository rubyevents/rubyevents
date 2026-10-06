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

  test "skips sponsors whose name parameterizes to an empty slug" do
    with_temp_sponsors([
      {"name" => "株式会社スマートバンク", "slug" => "kabushikigaishisuma-tobank", "website" => "https://example.com"}
    ]) do |path|
      assert_empty Static::Validators::SponsorSlug.new(file_path: path).errors
    end
  end

  test "fixes slugs by replacing them with the parameterized name" do
    with_temp_sponsors([
      {"name" => "Acme Corp", "slug" => "acme", "website" => "https://acme.com"}
    ]) do |path|
      result = Static::Validators::SponsorSlug.new(file_path: path).fix

      assert_equal({changed: 1, file_path: path}, result)
      assert_equal "acme-corp", sponsor_in_file(path, "Acme Corp").value_at("slug")
    end
  end

  test "fixes every mismatched slug in a file" do
    with_temp_sponsors([
      {"name" => "Acme Corp", "slug" => "acme", "website" => "https://acme.com"},
      {"name" => "GitButler", "slug" => "git_butler", "website" => "https://gitbutler.com"},
      {"name" => "Jelly", "slug" => "jelly", "website" => "https://letsjelly.com"}
    ]) do |path|
      result = Static::Validators::SponsorSlug.new(file_path: path).fix

      assert_equal 2, result[:changed]
      assert_equal "acme-corp", sponsor_in_file(path, "Acme Corp").value_at("slug")
      assert_equal "gitbutler", sponsor_in_file(path, "GitButler").value_at("slug")
      assert_equal "jelly", sponsor_in_file(path, "Jelly").value_at("slug")
    end
  end

  test "does not save the file when no slugs need fixing" do
    with_temp_sponsors([
      {"name" => "Acme Corp", "slug" => "acme-corp", "website" => "https://acme.com"}
    ]) do |path|
      validator = Static::Validators::SponsorSlug.new(file_path: path)
      original_content = File.read(path)

      assert_empty validator.errors

      assert_nil validator.fix

      assert_equal original_content, File.read(path), "fix should not write a file it has nothing to fix"
    end
  end

  test "fixes slugs across multiple tiers" do
    dir = Dir.mktmpdir
    path = File.join(dir, "data", "rubyconf", "2025", "sponsors.yml")

    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, [{
      "tiers" => [
        {"name" => "Gold", "level" => 1, "sponsors" => [{"name" => "SmartBank, Inc.", "slug" => "SmartBankInc", "website" => "https://smartbank.co.jp"}]},
        {"name" => "Silver", "level" => 2, "sponsors" => [{"name" => "FjordBootCamp", "slug" => "FjordBootCamp", "website" => "https://fjordbootcamp.com"}]}
      ]
    }].to_yaml)

    result = Static::Validators::SponsorSlug.new(file_path: path).fix

    assert_equal 2, result[:changed]
    assert_equal "smartbank-inc", sponsor_in_file(path, "SmartBank, Inc.").value_at("slug")
    assert_equal "fjordbootcamp", sponsor_in_file(path, "FjordBootCamp").value_at("slug")
  ensure
    FileUtils.rm_rf(dir)
  end

  test "leaves sponsors whose name parameterizes to an empty slug alone" do
    with_temp_sponsors([
      {"name" => "株式会社スマートバンク", "slug" => "kabushikigaishisuma-tobank", "website" => "https://example.com"}
    ]) do |path|
      original_content = File.read(path)

      assert_nil Static::Validators::SponsorSlug.new(file_path: path).fix

      assert_equal original_content, File.read(path)
    end
  end

  test "fix does not write files it is not applicable to" do
    file = Dir.glob(Rails.root.join("data/**/event.yml")).first
    original_content = File.read(file)

    assert_nil Static::Validators::SponsorSlug.new(file_path: file).fix

    assert_equal original_content, File.read(file)
  end

  private

  def sponsor_in_file(path, name)
    sponsors = Yerba.parse_file(path)["[0].tiers[].sponsors[]"]

    sponsors.find { |sponsor| sponsor.value_at("name") == name }
  end

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
