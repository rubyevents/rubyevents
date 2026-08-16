# frozen_string_literal: true

require "test_helper"

class Static::Validators::SlugMatchesNameTest < ActiveSupport::TestCase
  SPEAKERS_FILE = Rails.root.join("data/speakers.yml").to_s

  test "applicable? returns true for speakers.yml" do
    validator = Static::Validators::SlugMatchesName.new(file_path: SPEAKERS_FILE)
    assert validator.applicable?
  end

  test "applicable? returns false for a non-speakers file" do
    file = Dir.glob(Rails.root.join("data/**/event.yml")).first
    validator = Static::Validators::SlugMatchesName.new(file_path: file)
    assert_not validator.applicable?
  end

  test "applicable? returns false for a non-existent file" do
    validator = Static::Validators::SlugMatchesName.new(file_path: "/nonexistent/speakers.yml")
    assert_not validator.applicable?
  end

  test "returns empty errors for the real speakers.yml" do
    validator = Static::Validators::SlugMatchesName.new(file_path: SPEAKERS_FILE)
    errors = validator.errors
    assert errors.all? { |e| e.is_a?(Static::Validators::Error) }
  end

  test "returns error for GitHub profile instead of slug" do
    yaml = <<~YAML
      ---
      - name: Rachael Wright-Munn
        github: chaelcodes
        slug: chaelcodes
    YAML
    with_temp_speakers_yaml(yaml) do |path|
      validator = Static::Validators::SlugMatchesName.new(file_path: path)
      errors = validator.errors
      error = errors.first
      assert_equal "Slug must be the name parameterized, expected: rachael-wright-munn", error.to_h["message"]
      assert_equal 1, error.to_h["line"]
      assert_equal 3, error.to_h["end_line"]
    end
  end

  test "returns error for non-slug slug" do
    yaml = <<~YAML
      ---
      - name: Rachael Wright-Munn
        slug: RachaelWrightMunn
    YAML
    with_temp_speakers_yaml(yaml) do |path|
      validator = Static::Validators::SlugMatchesName.new(file_path: path)
      errors = validator.errors
      assert errors.any? { |e| e.to_h["message"].include?("Slug must be the name parameterized, expected: rachael-wright-munn") }
    end
  end

  test "returns no error for valid slug" do
    yaml = <<~YAML
      ---
      - name: Rachael Wright-Munn
        github: chaelcodes
        slug: rachael-wright-munn
    YAML
    with_temp_speakers_yaml(yaml) do |path|
      validator = Static::Validators::SlugMatchesName.new(file_path: path)
      assert_empty validator.errors
    end
  end

  test "no errors for alias slugs that are parameterized names" do
    yaml = <<~YAML
      ---
      - name: Yukihiro "Matz" Matsumoto
        github: matz
        twitter: yukihiro_matz
        bluesky: matz.bsky.social
        website: https://matz.rubyist.net
        speakerdeck: matz
        slug: yukihiro-matz-matsumoto
        aliases:
          - name: Matz
            slug: matz
          - name: Yukihiro 'Matz' Matsumoto
            slug: yukihiro-matz-matsumoto
          - name: Yukihiro Matsumoto
            slug: yukihiro-matsumoto
          - name: Yukihiro Matz Matsumoto
            slug: yukihiro-matz-matsumoto
          - name: Yukihiro Matzumoto
            slug: yukihiro-matzumoto
          - name: まつもとゆきひろ
            slug: yukihiro-matsumoto
    YAML
    with_temp_speakers_yaml(yaml) do |path|
      validator = Static::Validators::SlugMatchesName.new(file_path: path)
      assert_empty validator.errors
    end
  end

  test "errors for alias not being a parameterized name" do
    yaml = <<~YAML
      ---
      - name: Yukihiro "Matz" Matsumoto
        github: matz
        twitter: yukihiro_matz
        bluesky: matz.bsky.social
        website: https://matz.rubyist.net
        speakerdeck: matz
        slug: yukihiro-matz-matsumoto
        aliases:
          - name: Matz
            slug: Matz
    YAML
    with_temp_speakers_yaml(yaml) do |path|
      validator = Static::Validators::SlugMatchesName.new(file_path: path)
      errors = validator.errors
      assert errors.any? { |e| e.to_h["message"].include?("Slug must be the name parameterized, expected: matz") }
    end
  end

  test "reports correct line number for speaker with bad slug" do
    yaml = <<~YAML
      ---
      - name: Rachael Wright-Munn
        slug: chaelcodes
    YAML
    with_temp_speakers_yaml(yaml) do |path|
      validator = Static::Validators::SlugMatchesName.new(file_path: path)
      errors = validator.errors
      assert_equal 1, errors.size
      assert_equal 2, errors.first.to_h["line"]
      assert_equal 3, errors.first.to_h["end_line"]
    end
  end

  test "reports correct line number for alias with bad slug" do
    yaml = <<~YAML
      ---
      - name: Matz
        slug: matz
        aliases:
          - name: Matz
            slug: Matz
    YAML
    with_temp_speakers_yaml(yaml) do |path|
      validator = Static::Validators::SlugMatchesName.new(file_path: path)
      errors = validator.errors
      assert_equal 1, errors.size
      assert_equal 5, errors.first.to_h["line"]
      assert_equal 6, errors.first.to_h["end_line"]
    end
  end

  test "errors are Static::Validators::Error objects" do
    yaml = <<~YAML
      ---
      - name: Rachael Wright-Munn
        slug: RachaelWrightMunn
    YAML
    with_temp_speakers_yaml(yaml) do |path|
      validator = Static::Validators::SlugMatchesName.new(file_path: path)
      assert validator.errors.all? { |e| e.is_a?(Static::Validators::Error) }
    end
  end

  private

  def with_temp_speakers_yaml(yaml_content)
    dir = Dir.mktmpdir
    path = File.join(dir, "data", "speakers.yml")
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, yaml_content)
    yield path
  ensure
    FileUtils.rm_rf(dir)
  end
end
