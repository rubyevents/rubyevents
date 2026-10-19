# frozen_string_literal: true

require "test_helper"

class Static::Validators::DuplicateSeriesSocialsTest < ActiveSupport::TestCase
  include StaticDataSandbox

  test "applicable? returns false for a non-event.yml file" do
    file = Dir.glob(Rails.root.join("data/**/videos.yml")).first
    validator = Static::Validators::DuplicateSeriesSocials.new(file_path: file)
    assert_not validator.applicable?
  end

  test "returns empty errors when the event socials differ from the series" do
    with_temp_series(%(twitter: "testconf"), %(twitter: "testconf2025")) do |path|
      assert_empty Static::Validators::DuplicateSeriesSocials.new(file_path: path).errors
    end
  end

  test "returns empty errors when only the series defines the social" do
    with_temp_series(%(twitter: "testconf"), "") do |path|
      assert_empty Static::Validators::DuplicateSeriesSocials.new(file_path: path).errors
    end
  end

  test "returns empty errors when there is no series.yml" do
    with_temp_series(nil, %(twitter: "testconf")) do |path|
      assert_empty Static::Validators::DuplicateSeriesSocials.new(file_path: path).errors
    end
  end

  test "returns an error for each social also defined on the series" do
    series = %(twitter: "testconf"\nmastodon: "https://ruby.social/@testconf")
    event = %(twitter: "testconf"\nmastodon: "https://ruby.social/@testconf")

    with_temp_series(series, event) do |path|
      errors = Static::Validators::DuplicateSeriesSocials.new(file_path: path).errors

      assert_equal 2, errors.count
      assert errors.any? { |e| e.message.start_with?("twitter (testconf)") && e.message.include?("remove it from event.yml") }
      assert errors.any? { |e| e.message.start_with?("mastodon (https://ruby.social/@testconf)") }
    end
  end

  test "treats handles that only differ by case, @ or trailing slash as duplicates" do
    series = %(twitter: "TestConf"\nmastodon: "https://ruby.social/@testconf/")
    event = %(twitter: "@testconf"\nmastodon: "https://ruby.social/@testconf")

    with_temp_series(series, event) do |path|
      assert_equal 2, Static::Validators::DuplicateSeriesSocials.new(file_path: path).errors.count
    end
  end

  test "fix removes the duplicated socials from event.yml" do
    with_temp_series(%(twitter: "testconf"), %(twitter: "testconf"\nmastodon: "https://ruby.social/@testconf2025")) do |path|
      result = Static::Validators::DuplicateSeriesSocials.new(file_path: path).fix

      assert_equal 1, result[:changed]
      assert_empty Static::Validators::DuplicateSeriesSocials.new(file_path: path).errors
      assert_not_includes File.read(path), "twitter:"
      assert_includes File.read(path), %(mastodon: "https://ruby.social/@testconf2025")
    end
  end

  private

  def with_temp_series(series_socials, event_socials)
    with_static_data_dir do |dir|
      series_path = File.join(dir, "data", "testconf", "series.yml")
      path = File.join(dir, "data", "testconf", "testconf-2025", "event.yml")
      FileUtils.mkdir_p(File.dirname(path))

      File.write(series_path, %(---\nid: "testconf"\nname: "TestConf"\n#{series_socials}\n)) if series_socials
      File.write(path, %(---\nid: "testconf-2025"\ntitle: "TestConf 2025"\n#{event_socials}\n))

      yield path
    end
  end
end
