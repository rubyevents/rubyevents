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

  test "errors when name cannot be parameterized, suggesting a romanized name or the GitHub handle" do
    yaml = <<~YAML
      ---
      - name: まつもとゆきひろ
        github: matz
        slug: matz
    YAML
    with_temp_speakers_yaml(yaml) do |path|
      errors = Static::Validators::SpeakerSlugMatchesName.new(file_path: path).errors
      error = errors.first.to_h

      assert_equal 1, errors.size
      assert_equal %(Name "まつもとゆきひろ" cannot be parameterized into a stable slug. Use a romanized name, or the GitHub handle "matz" if none is known, as the name and add "まつもとゆきひろ" to aliases.), error["message"]
      assert_equal 4, error["line"]
    end
  end

  test "errors when name cannot be parameterized and there is no GitHub handle, suggesting a romanized name" do
    yaml = <<~YAML
      ---
      - name: しぶやあや
        github: ""
        slug: shibuya-aya
    YAML
    with_temp_speakers_yaml(yaml) do |path|
      errors = Static::Validators::SpeakerSlugMatchesName.new(file_path: path).errors

      assert_equal [%(Name "しぶやあや" cannot be parameterized into a stable slug. Use a romanized name as the name and add "しぶやあや" to aliases.)], errors.map { |e| e.to_h["message"] }
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

  test "fix uses the GitHub handle as the name and keeps the old name as an alias" do
    yaml = <<~YAML
      ---
      - name: "まつもとゆきひろ"
        github: "matz"
        slug: "matz"
    YAML
    with_temp_speakers_yaml(yaml) do |path|
      result = Static::Validators::SpeakerSlugMatchesName.new(file_path: path).fix
      speaker = Yerba.parse_file(path).root.first

      assert_equal({changed: 1, file_path: path}, result)
      assert_equal "matz", speaker["name"].value
      assert_equal "matz", speaker["slug"].value
      assert_equal ["まつもとゆきひろ"], speaker["aliases"].map(&:value)
      assert_not_includes speaker.keys, "slugs"
      assert_empty Static::Validators::SpeakerSlugMatchesName.new(file_path: path).errors
    end
  end

  test "fix regenerates a mismatched slug and keeps the old one as a redirect" do
    yaml = <<~YAML
      ---
      - name: "Rachael Wright-Munn"
        github: "chaelcodes"
        slug: "rachael-munn"
    YAML
    with_temp_speakers_yaml(yaml) do |path|
      Static::Validators::SpeakerSlugMatchesName.new(file_path: path).fix
      speaker = Yerba.parse_file(path).root.first

      assert_equal "rachael-wright-munn", speaker["slug"].value
      assert_equal ["rachael-munn"], speaker["slugs"].map(&:value)
    end
  end

  test "fix doesn't keep a slug equal to the GitHub handle as a redirect" do
    yaml = <<~YAML
      ---
      - name: "Rachael Wright-Munn"
        github: "chaelcodes"
        slug: "chaelcodes"
    YAML
    with_temp_speakers_yaml(yaml) do |path|
      Static::Validators::SpeakerSlugMatchesName.new(file_path: path).fix
      speaker = Yerba.parse_file(path).root.first

      assert_equal "rachael-wright-munn", speaker["slug"].value
      assert_not_includes speaker.keys, "slugs"
    end
  end

  test "fix leaves names without a GitHub handle for a human to romanize" do
    yaml = <<~YAML
      ---
      - name: "しぶやあや"
        github: ""
        slug: "shibuya-aya"
    YAML
    with_temp_speakers_yaml(yaml) do |path|
      assert_no_changes -> { File.read(path) } do
        assert_nil Static::Validators::SpeakerSlugMatchesName.new(file_path: path).fix
      end
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
