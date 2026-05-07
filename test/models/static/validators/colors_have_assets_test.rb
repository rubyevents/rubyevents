# frozen_string_literal: true

require "test_helper"

class Static::Validators::ColorsHaveAssetsTest < ActiveSupport::TestCase
  VALID_EVENT_FILE = Dir.glob(Rails.root.join("data/**/event.yml")).first.to_s

  test "applicable? returns true for an event.yml file" do
    validator = Static::Validators::ColorsHaveAssets.new(file_path: VALID_EVENT_FILE)
    assert validator.applicable?
  end

  test "applicable? returns false for a non-event file" do
    file = Dir.glob(Rails.root.join("data/**/videos.yml")).first.to_s
    validator = Static::Validators::ColorsHaveAssets.new(file_path: file)
    assert_not validator.applicable?
  end

  test "applicable? returns false for a non-existent file" do
    validator = Static::Validators::ColorsHaveAssets.new(file_path: "/nonexistent/event.yml")
    assert_not validator.applicable?
  end

  test "returns empty errors when no color fields are configured" do
    event = {"name" => "TestConf", "kind" => "conference"}.to_yaml
    with_temp_event(event) do |file_path|
      validator = Static::Validators::ColorsHaveAssets.new(file_path: file_path)
      assert_empty validator.errors
    end
  end

  test "returns error when banner_background set but asset missing" do
    event = {"name" => "TestConf", "banner_background" => "#ff0000"}.to_yaml
    with_temp_event(event) do |file_path|
      validator = Static::Validators::ColorsHaveAssets.new(file_path: file_path)
      assert validator.errors.any? { |e| e.to_h["message"].include?("banner.webp") }
    end
  end

  test "returns error when featured_color set but asset missing" do
    event = {"name" => "TestConf", "featured_color" => "#ff0000"}.to_yaml
    with_temp_event(event) do |file_path|
      validator = Static::Validators::ColorsHaveAssets.new(file_path: file_path)
      assert validator.errors.any? { |e| e.to_h["message"].include?("featured.webp") }
    end
  end

  test "deduplicates asset errors when multiple fields map to the same asset" do
    event = {"name" => "TestConf", "featured_background" => "#fff", "featured_color" => "#000"}.to_yaml
    with_temp_event(event) do |file_path|
      validator = Static::Validators::ColorsHaveAssets.new(file_path: file_path)
      # featured_background and featured_color both map to featured.webp — only one error
      assert_equal 1, validator.errors.count
    end
  end

  test "errors are Static::Validators::Error objects" do
    event = {"name" => "TestConf", "banner_background" => "#ff0000"}.to_yaml
    with_temp_event(event) do |file_path|
      validator = Static::Validators::ColorsHaveAssets.new(file_path: file_path)
      assert validator.errors.all? { |e| e.is_a?(Static::Validators::Error) }
    end
  end

  test "returns empty errors for all real event.yml files" do
    errors = Dir.glob(Rails.root.join("data/**/event.yml")).flat_map do |f|
      Static::Validators::ColorsHaveAssets.new(file_path: f).errors
    end
    assert_empty errors
  end

  private

  def with_temp_event(event_yaml)
    dir = Dir.mktmpdir
    file_path = File.join(dir, "data", "testconf", "2025", "event.yml")
    FileUtils.mkdir_p(File.dirname(file_path))
    File.write(file_path, event_yaml)
    yield file_path
  ensure
    FileUtils.rm_rf(dir)
  end
end
