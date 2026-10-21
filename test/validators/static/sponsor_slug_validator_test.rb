# frozen_string_literal: true

require "test_helper"

class Static::SponsorSlugValidatorTest < ActiveSupport::TestCase
  test "allows slugs that are the parameterized name" do
    with_sponsors(<<~YAML) do |path|
      - name: Acme Corp
        slug: acme-corp
      - name: GitButler
        slug: gitbutler
      - name: Foo & Bar
        slug: foo-bar
    YAML
      assert_empty errors_for(path)
    end
  end

  test "flags a slug that isn't the parameterized name" do
    with_sponsors(<<~YAML) do |path|
      - name: Acme Corp
        slug: acme
    YAML
      assert_equal [[6, %(slug "acme" does not match the parameterized name "acme-corp" for sponsor "Acme Corp". Run `bin/rails validate:fix` to update it.)]], errors_for(path)
    end
  end

  test "flags every mismatched slug" do
    with_sponsors(<<~YAML) do |path|
      - name: Acme Corp
        slug: acme
      - name: Ruby Central
        slug: rubycentral
    YAML
      assert_equal 2, errors_for(path).size
    end
  end

  test "skips sponsors whose name parameterizes to an empty slug" do
    with_sponsors(<<~YAML) do |path|
      - name: 株式会社スマートバンク
        slug: kabushikigaishisuma-tobank
    YAML
      assert_empty errors_for(path)
    end
  end

  test "fixes every mismatched slug in a file" do
    with_sponsors(<<~YAML) do |path|
      - name: Acme Corp
        slug: acme
      - name: GitButler
        slug: git_butler
      - name: Jelly
        slug: jelly
    YAML
      fixes = Yerba::Record.fix_all(sponsors_in(path), only: Static::SponsorSlugValidator)

      assert_equal 2, fixes.sum(&:last)
      assert_equal %w[acme-corp gitbutler jelly], sponsors_in(path).map(&:slug)
    end
  end

  test "fixes slugs across multiple tiers" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "data", "rubyconf", "2025", "sponsors.yml")
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, <<~YAML)
        - tiers:
            - name: Gold
              level: 1
              sponsors:
                - name: SmartBank, Inc.
                  slug: SmartBankInc
            - name: Silver
              level: 2
              sponsors:
                - name: FjordBootCamp
                  slug: FjordBootCamp
      YAML

      fixes = Yerba::Record.fix_all(sponsors_in(path), only: Static::SponsorSlugValidator)

      assert_equal 2, fixes.sum(&:last)
      assert_equal %w[smartbank-inc fjordbootcamp], sponsors_in(path).map(&:slug)
    end
  end

  test "does not write the file when no slugs need fixing" do
    with_sponsors(<<~YAML) do |path|
      - name: Acme Corp
        slug: acme-corp
      - name: 株式会社スマートバンク
        slug: kabushikigaishisuma-tobank
    YAML
      original = File.read(path)

      assert_empty Yerba::Record.fix_all(sponsors_in(path), only: Static::SponsorSlugValidator)
      assert_equal original, File.read(path)
    end
  end

  private

  def sponsors_in(path)
    Static::Sponsor.in_file(path).first.tiers.flat_map { |tier| tier.sponsors.to_a }
  end

  def errors_for(path)
    sponsors_in(path).flat_map do |sponsor|
      sponsor.valid?
      sponsor.errors.map { |error| [sponsor.error_location(error)&.start_line, error.full_message] }
    end
  end

  def with_sponsors(sponsors_yaml)
    Dir.mktmpdir do |dir|
      path = File.join(dir, "data", "rubyconf", "2025", "sponsors.yml")
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, "- tiers:\n    - name: Gold\n      level: 1\n      sponsors:\n#{sponsors_yaml.indent(8)}")

      yield path
    end
  end
end
