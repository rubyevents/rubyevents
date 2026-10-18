# frozen_string_literal: true

require "test_helper"

class Static::Validators::MissingSeriesSocialsTest < ActiveSupport::TestCase
  test "applicable? returns false for a non-event.yml file" do
    file = Dir.glob(Rails.root.join("data/**/videos.yml")).first
    validator = Static::Validators::MissingSeriesSocials.new(file_path: file)
    assert_not validator.applicable?
  end

  test "returns empty errors when the series defines the social" do
    with_temp_series(%(twitter: "testconf"), {"testconf-2025" => %(twitter: "testconf2025")}) do |paths|
      assert_empty Static::Validators::MissingSeriesSocials.new(file_path: paths["testconf-2025"]).errors
    end
  end

  test "returns empty errors when there is no series.yml" do
    with_temp_series(nil, {"testconf-2025" => %(twitter: "testconf")}) do |paths|
      assert_empty Static::Validators::MissingSeriesSocials.new(file_path: paths["testconf-2025"]).errors
    end
  end

  test "ignores links that can point at a single edition" do
    event = %(github: "https://github.com/testconf/2025"\nluma: "https://lu.ma/testconf2025"\nmeetup: "https://www.meetup.com/testconf")

    with_temp_series("", {"testconf-2025" => event}) do |paths|
      assert_empty Static::Validators::MissingSeriesSocials.new(file_path: paths["testconf-2025"]).errors
    end
  end

  test "returns an error for each account missing from the series" do
    event = %(twitter: "testconf"\nmastodon: "https://ruby.social/@testconf")

    with_temp_series("", {"testconf-2025" => event}) do |paths|
      errors = Static::Validators::MissingSeriesSocials.new(file_path: paths["testconf-2025"]).errors

      assert_equal 2, errors.count
      assert errors.any? { |e| e.message.start_with?("twitter (testconf)") && e.message.include?("move it to series.yml") }
      assert errors.any? { |e| e.message.start_with?("mastodon (https://ruby.social/@testconf)") }
    end
  end

  test "fix moves the account from event.yml to series.yml" do
    with_temp_series("", {"testconf-2025" => %(twitter: "testconf")}) do |paths|
      result = Static::Validators::MissingSeriesSocials.new(file_path: paths["testconf-2025"]).fix

      assert_equal 1, result[:changed]
      assert_empty Static::Validators::MissingSeriesSocials.new(file_path: paths["testconf-2025"]).errors
      assert_not_includes File.read(paths["testconf-2025"]), "twitter:"
      assert_equal "testconf", Yerba.parse_file(paths[:series]).value_at("twitter")
    end
  end

  test "fix leaves the account in place when another edition uses a different one" do
    editions = {"testconf-2025" => %(twitter: "testconf"), "testconf-2026" => %(twitter: "testconf2026")}

    with_temp_series("", editions) do |paths|
      assert_nil Static::Validators::MissingSeriesSocials.new(file_path: paths["testconf-2025"]).fix
      assert_includes File.read(paths["testconf-2025"]), %(twitter: "testconf")
      assert_not_includes File.read(paths[:series]), "twitter:"
    end
  end

  private

  def with_temp_series(series_socials, events)
    dir = Dir.mktmpdir
    series_path = File.join(dir, "data", "testconf", "series.yml")
    paths = {series: series_path}

    events.each do |slug, socials|
      path = File.join(dir, "data", "testconf", slug, "event.yml")
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, %(---\nid: "#{slug}"\ntitle: "TestConf"\n#{socials}\n))
      paths[slug] = path
    end

    File.write(series_path, %(---\nid: "testconf"\nname: "TestConf"\n#{series_socials}\n)) if series_socials

    yield paths
  ensure
    FileUtils.rm_rf(dir)
  end
end
