# frozen_string_literal: true

require "test_helper"

class Static::Validators::SpeakerSlugMatchesNameTest < ActiveSupport::TestCase
  self.fixture_table_names = []
  SPEAKERS_FILE = Rails.root.join("data/speakers.yml").to_s

  test "applicable? returns true for speakers.yml" do
    validator = Static::Validators::SpeakerSlugMatchesName.new(file_path: SPEAKERS_FILE)
    assert validator.applicable?
  end

  test "applicable? returns false for a non-speakers file" do
    file = Dir.glob(Rails.root.join("data/**/event.yml")).first
    validator = Static::Validators::SpeakerSlugMatchesName.new(file_path: file)
    assert_not validator.applicable?
  end

  test "applicable? returns false for a non-existent file" do
    validator = Static::Validators::SpeakerSlugMatchesName.new(file_path: "/nonexistent/speakers.yml")
    assert_not validator.applicable?
  end

  test "returns empty errors for the real speakers.yml" do
    validator = Static::Validators::SpeakerSlugMatchesName.new(file_path: SPEAKERS_FILE)
    assert_empty validator.errors
  end

  test "returns error for GitHub profile instead of slug" do
    yaml = <<~YAML
      ---
      - name: Rachael Wright-Munn
        github: chaelcodes
        slug: chaelcodes
    YAML
    with_temp_speakers_yaml(yaml) do |path|
      validator = Static::Validators::SpeakerSlugMatchesName.new(file_path: path)
      errors = validator.errors
      error = errors.first.to_h
      assert_equal "Slug must be the name parameterized, expected: rachael-wright-munn", error["message"]
      assert_equal 4, error["line"], "Line number #{error["line"]} does not match line number 4."
      assert_equal 4, error["end_line"], "End line number #{error["end_line"]} does not match line number 4."
    end
  end

  test "returns error for non-slug slug" do
    yaml = <<~YAML
      ---
      - name: Rachael Wright-Munn
        slug: RachaelWrightMunn
    YAML
    with_temp_speakers_yaml(yaml) do |path|
      validator = Static::Validators::SpeakerSlugMatchesName.new(file_path: path)
      errors = validator.errors
      error = errors.first.to_h
      assert_equal "Slug must be the name parameterized, expected: rachael-wright-munn", error["message"]
      assert_equal 3, error["line"], "Line number #{error["line"]} does not match line number 3."
      assert_equal 3, error["end_line"], "End line number #{error["end_line"]} does not match line number 3."
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
      validator = Static::Validators::SpeakerSlugMatchesName.new(file_path: path)
      assert_empty validator.errors
    end
  end

  test "no errors when name cannot be parameterized and slug matches github handle" do
    yaml = <<~YAML
      ---
      - name: まつもとゆきひろ
        github: matz
        slug: matz
    YAML
    with_temp_speakers_yaml(yaml) do |path|
      validator = Static::Validators::SpeakerSlugMatchesName.new(file_path: path)
      assert_empty validator.errors
    end
  end

  test "errors for github handle slug when name cannot be parameterized" do
    yaml = <<~YAML
      ---
      - name: まつもとゆきひろ
        github: matz
        slug: ruby
    YAML
    with_temp_speakers_yaml(yaml) do |path|
      validator = Static::Validators::SpeakerSlugMatchesName.new(file_path: path)
      errors = validator.errors
      error = errors.first.to_h
      assert_equal "Name cannot be parameterized. Slug must be the GitHub handle, expected: matz.", error["message"]
      assert_equal 4, error["line"], "Line number #{error["line"]} does not match line number 4."
      assert_equal 4, error["end_line"], "End line number #{error["end_line"]} does not match line number 4."
    end
  end

  test "no errors for any slug when name cannot be parameterized and no github handle" do
    yaml = <<~YAML
      ---
      - name: まつもとゆきひろ
        slug: yukihiro-matsumoto
    YAML
    with_temp_speakers_yaml(yaml) do |path|
      validator = Static::Validators::SpeakerSlugMatchesName.new(file_path: path)
      assert_empty validator.errors
    end
  end

  test "no errors for alias with unparameterizable name not matching speaker github handle" do
    yaml = <<~YAML
      ---
      - name: NARUSE Yui
        github: nurse
        slug: naruse-yui
        aliases:
          - name: 成瀬ゆい
            slug: naruse-yui
    YAML
    with_temp_speakers_yaml(yaml) do |path|
      validator = Static::Validators::SpeakerSlugMatchesName.new(file_path: path)
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
      validator = Static::Validators::SpeakerSlugMatchesName.new(file_path: path)
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
      validator = Static::Validators::SpeakerSlugMatchesName.new(file_path: path)
      errors = validator.errors
      error = errors.first.to_h
      assert_equal "Slug must be the name parameterized, expected: matz", error["message"]
      assert_equal 11, error["line"], "Line number #{error["line"]} does not match line number 11."
      assert_equal 11, error["end_line"], "End line number #{error["end_line"]} does not match line number 11."
    end
  end

  test "errors are Static::Validators::Error objects" do
    yaml = <<~YAML
      ---
      - name: Rachael Wright-Munn
        slug: RachaelWrightMunn
    YAML
    with_temp_speakers_yaml(yaml) do |path|
      validator = Static::Validators::SpeakerSlugMatchesName.new(file_path: path)
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
