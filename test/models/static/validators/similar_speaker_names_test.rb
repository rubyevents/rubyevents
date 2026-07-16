# frozen_string_literal: true

require "test_helper"

class Static::Validators::SimilarSpeakerNamesTest < ActiveSupport::TestCase
  SPEAKERS_FILE = Rails.root.join("data/speakers.yml").to_s

  test "applicable? returns true for speakers.yml" do
    validator = Static::Validators::SimilarSpeakerNames.new(file_path: SPEAKERS_FILE)
    assert validator.applicable?
  end

  test "applicable? returns false for a non-speakers file" do
    file = Dir.glob(Rails.root.join("data/**/event.yml")).first
    validator = Static::Validators::SimilarSpeakerNames.new(file_path: file)
    assert_not validator.applicable?
  end

  test "flags a similar-named speaker with no social handle" do
    yaml = [
      {"name" => "Pat Shaughnessy", "slug" => "pat-shaughnessy", "github" => "pat"},
      {"name" => "Pat Saughnessy", "slug" => "pat-saughnessy", "github" => ""}
    ].to_yaml

    with_temp_speakers_yaml(yaml) do |path|
      errors = Static::Validators::SimilarSpeakerNames.new(file_path: path).errors

      assert_equal 1, errors.size
      assert errors.first.to_h["message"].include?("Pat Saughnessy")
      assert errors.first.to_h["message"].include?("no social handle")
    end
  end

  test "does not flag when the similar-named speaker has any social handle" do
    yaml = [
      {"name" => "Pat Shaughnessy", "slug" => "pat-shaughnessy", "github" => "pat"},
      {"name" => "Pat Saughnessy", "slug" => "pat-saughnessy", "mastodon" => "@pat@ruby.social"}
    ].to_yaml

    with_temp_speakers_yaml(yaml) do |path|
      assert_empty Static::Validators::SimilarSpeakerNames.new(file_path: path).errors
    end
  end

  test "flags both members when neither has a handle" do
    yaml = [
      {"name" => "James Edward-Jones", "slug" => "james-edward-jones", "github" => ""},
      {"name" => "James Edwards-Jones", "slug" => "james-edwards-jones", "github" => ""}
    ].to_yaml

    with_temp_speakers_yaml(yaml) do |path|
      errors = Static::Validators::SimilarSpeakerNames.new(file_path: path).errors
      assert_equal 2, errors.size
    end
  end

  test "does not flag distinct names lacking handles" do
    yaml = [
      {"name" => "Aaron Patterson", "slug" => "aaron-patterson", "github" => ""},
      {"name" => "Yukihiro Matsumoto", "slug" => "yukihiro-matsumoto", "github" => ""}
    ].to_yaml

    with_temp_speakers_yaml(yaml) do |path|
      assert_empty Static::Validators::SimilarSpeakerNames.new(file_path: path).errors
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
