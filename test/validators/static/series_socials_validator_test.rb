# frozen_string_literal: true

require "test_helper"

class Static::SeriesSocialsValidatorTest < ActiveSupport::TestCase
  include StaticDataSandbox

  test "socials that differ from the series are valid" do
    with_series(%(twitter: "testconf"), "testconf-2025" => %(twitter: "testconf2025")) do |events|
      assert_empty social_errors(events["testconf-2025"])
    end
  end

  test "socials only defined on the series are valid" do
    with_series(%(twitter: "testconf"), "testconf-2025" => "") do |events|
      assert_empty social_errors(events["testconf-2025"])
    end
  end

  test "an event without a series.yml is valid" do
    with_series(nil, "testconf-2025" => %(twitter: "testconf")) do |events|
      assert_empty social_errors(events["testconf-2025"])
    end
  end

  test "flags each social also defined on the series" do
    socials = %(twitter: "testconf"\nmastodon: "https://ruby.social/@testconf")

    with_series(socials, "testconf-2025" => socials) do |events|
      event = events["testconf-2025"]

      assert_equal [
        "mastodon (https://ruby.social/@testconf) is already defined in series.yml — remove it from event.yml and keep it on series.yml. Run `bin/rails validate:fix` to remove it.",
        "twitter (testconf) is already defined in series.yml — remove it from event.yml and keep it on series.yml. Run `bin/rails validate:fix` to remove it."
      ], social_errors(event).sort
      assert_equal 6, event.error_location(event.errors.where(:twitter).first).start_line
    end
  end

  test "treats handles that only differ by case, @ or trailing slash as duplicates" do
    series = %(twitter: "TestConf"\nmastodon: "https://ruby.social/@testconf/")
    event = %(twitter: "@testconf"\nmastodon: "https://ruby.social/@testconf")

    with_series(series, "testconf-2025" => event) do |events|
      assert_equal 2, social_errors(events["testconf-2025"]).count { |message| message.include?("is already defined in series.yml") }
    end
  end

  test "flags each account missing from the series" do
    with_series("", "testconf-2025" => %(twitter: "testconf"\nmastodon: "https://ruby.social/@testconf")) do |events|
      assert_equal [
        "mastodon (https://ruby.social/@testconf) is not defined in series.yml — move it to series.yml so every event in the series shares it. Run `bin/rails validate:fix` to move it.",
        "twitter (testconf) is not defined in series.yml — move it to series.yml so every event in the series shares it. Run `bin/rails validate:fix` to move it."
      ], social_errors(events["testconf-2025"]).sort
    end
  end

  test "ignores missing links that can point at a single edition" do
    socials = %(github: "https://github.com/testconf/2025"\nluma: "https://lu.ma/testconf2025"\nmeetup: "https://www.meetup.com/testconf")

    with_series("", "testconf-2025" => socials) do |events|
      assert_empty social_errors(events["testconf-2025"])
    end
  end

  test "fix removes the duplicated socials from event.yml" do
    series = %(twitter: "testconf"\nmastodon: "https://ruby.social/@testconf")

    with_series(series, "testconf-2025" => %(twitter: "testconf"\nmastodon: "https://ruby.social/@testconf2025")) do |events, paths|
      Yerba::Record.fix_all([events["testconf-2025"]], only: Static::SeriesSocialsValidator)

      assert_not_includes File.read(paths["testconf-2025"]), "twitter:"
      assert_includes File.read(paths["testconf-2025"]), %(mastodon: "https://ruby.social/@testconf2025")
      assert_includes File.read(paths[:series]), %(twitter: "testconf")
    end
  end

  test "fix moves the missing account from event.yml to series.yml" do
    with_series("", "testconf-2025" => %(twitter: "testconf")) do |events, paths|
      Yerba::Record.fix_all([events["testconf-2025"]], only: Static::SeriesSocialsValidator)

      assert_not_includes File.read(paths["testconf-2025"]), "twitter:"
      assert_equal "testconf", Yerba.parse_file(paths[:series]).value_at("twitter")
    end
  end

  test "fix leaves the account in place when another edition uses a different one" do
    with_series("", "testconf-2025" => %(twitter: "testconf"), "testconf-2026" => %(twitter: "testconf2026")) do |events, paths|
      assert_empty Yerba::Record.fix_all([events["testconf-2025"]], only: Static::SeriesSocialsValidator)
      assert_includes File.read(paths["testconf-2025"]), %(twitter: "testconf")
      assert_not_includes File.read(paths[:series]), "twitter:"
    end
  end

  private

  def social_errors(event)
    event.valid?(:lint)
    event.errors.full_messages.select { |message| message.include?("series.yml —") }
  end

  def with_series(series_socials, events)
    with_static_data_dir do |root|
      paths = {series: File.join(root, "data", "testconf", "series.yml")}

      events.each do |slug, socials|
        paths[slug] = File.join(root, "data", "testconf", slug, "event.yml")
        FileUtils.mkdir_p(File.dirname(paths[slug]))
        File.write(paths[slug], %(---\nid: "#{slug}"\ntitle: "TestConf"\nstart_date: "2025-05-01"\nend_date: "2025-05-02"\n#{socials}\n))
      end

      File.write(paths[:series], %(---\nid: "testconf"\nname: "TestConf"\n#{series_socials}\n)) if series_socials

      yield events.keys.to_h { |slug| [slug, Static::Event.in_file(paths[slug]).first] }, paths
    end
  end
end
