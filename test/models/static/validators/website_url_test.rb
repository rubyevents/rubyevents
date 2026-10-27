# frozen_string_literal: true

require "test_helper"

class Static::Validators::WebsiteURLTest < ActiveSupport::TestCase
  test "applicable? returns true for speakers.yml" do
    with_temp_file("speakers.yml", [{"name" => "Jane Doe", "website" => "https://janedoe.dev"}]) do |path|
      assert Static::Validators::WebsiteURL.new(file_path: path).applicable?
    end
  end

  test "applicable? returns false for event.yml" do
    with_temp_file("event.yml", {"website" => "https://x.com/rubyconf"}) do |path|
      assert_not Static::Validators::WebsiteURL.new(file_path: path).applicable?
    end
  end

  test "does not flag regular websites" do
    with_temp_speakers("https://janedoe.dev") do |path|
      assert_empty Static::Validators::WebsiteURL.new(file_path: path).errors
    end
  end

  test "does not flag hosts that merely end in x.com" do
    with_temp_speakers("https://box.com") do |path|
      assert_empty Static::Validators::WebsiteURL.new(file_path: path).errors
    end
  end

  test "flags t.co links" do
    with_temp_speakers("http://t.co/VKiTe81rKb") do |path|
      errors = Static::Validators::WebsiteURL.new(file_path: path).errors

      assert_equal 1, errors.size
      assert_match(%r{website "http://t.co/VKiTe81rKb"}, errors.first.message)
    end
  end

  test "flags twitter.com and x.com links, including subdomains" do
    %w[https://twitter.com/janedoe https://www.twitter.com/janedoe https://mobile.twitter.com/janedoe https://x.com/janedoe].each do |website|
      with_temp_speakers(website) do |path|
        assert_equal 1, Static::Validators::WebsiteURL.new(file_path: path).errors.size, "expected #{website} to be flagged"
      end
    end
  end

  test "only flags the offending speaker" do
    speakers = [
      {"name" => "Jane Doe", "slug" => "jane-doe", "website" => "https://janedoe.dev"},
      {"name" => "John Smith", "slug" => "john-smith", "website" => "https://t.co/abc123"}
    ]

    with_temp_file("speakers.yml", speakers) do |path|
      errors = Static::Validators::WebsiteURL.new(file_path: path).errors

      assert_equal 1, errors.size
      assert_match(%r{https://t.co/abc123}, errors.first.message)
      assert_equal 7, errors.first.line
    end
  end

  private

  def with_temp_speakers(website, &)
    with_temp_file("speakers.yml", [{"name" => "Jane Doe", "slug" => "jane-doe", "website" => website}], &)
  end

  def with_temp_file(filename, content)
    dir = Dir.mktmpdir
    path = File.join(dir, "data", "rubyconf", "2025", filename)

    FileUtils.mkdir_p(File.dirname(path))
    Yerba::Document.from(content, path: path).save!

    yield path
  ensure
    FileUtils.rm_rf(dir)
  end
end
