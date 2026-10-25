require "test_helper"
require "generators/newsletter/newsletter_generator"

class NewsletterGeneratorTest < Rails::Generators::TestCase
  class StubbedNewsletterGenerator < NewsletterGenerator
    source_root NewsletterGenerator.source_root

    private

    def fetch_pull_requests
      [
        {"number" => 1, "author" => {"login" => "chaelcodes", "name" => "Rachael Wright-Munn"}, "labels" => [{"name" => "data"}]},
        {"number" => 2, "author" => {"login" => "app/copilot-swe-agent", "name" => "Copilot"}, "labels" => []}
      ]
    end

    def data_changes
      Struct.new(:videos_markdown, :new_data_markdown).new(
        "📺 2 videos published for [Rails World 2023](/events/rails-world-2023/talks) in PR [1](https://github.com/rubyevents/rubyevents/pull/1)",
        "### New events\n\n📆 [Rails World 2024](/events/rails-world-2024) added in PR [1](https://github.com/rubyevents/rubyevents/pull/1)"
      )
    end
  end

  tests StubbedNewsletterGenerator

  setup do
    self.class.destination Dir.mktmpdir("newsletter_generator", Rails.root.join("tmp").to_s)
  end

  teardown do
    FileUtils.remove_entry(destination_root)
  end

  test "renders events, data changes and contributors" do
    run_generator ["October", "--year", "2023"]

    assert_file "content/announcements/2023-11-01-october-newsletter.md" do |content|
      assert_match(/title: "RubyEvents.org October 2023 Newsletter"/, content)
      assert_match(%r{📆 \[Rails World\]\(/events/rails-world-2023\)}, content)
      assert_match(/## Uploaded videos\n\n📺 2 videos published for \[Rails World 2023\]/, content)
      assert_match(/## New data\n\n### New events\n\n📆 \[Rails World 2024\]/, content)
      assert_match(/we merged \[2 PRs from 2 contributors!\]/, content)
      assert_match(/1 PRs were \[new event data and videos\]/, content)
      assert_includes content, "Rachael Wright-Munn(@chaelcodes)"
      assert_includes content, "🤖"
    end
  end
end
