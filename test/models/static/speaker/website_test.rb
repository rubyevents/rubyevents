# frozen_string_literal: true

require "test_helper"

class Static::Speaker::WebsiteTest < ActiveSupport::TestCase
  test "does not flag regular websites" do
    assert_empty website_errors("https://janedoe.dev")
  end

  test "does not flag hosts that merely end in x.com" do
    assert_empty website_errors("https://box.com")
  end

  test "flags t.co links" do
    assert_equal [%(website "http://t.co/VKiTe81rKb" points to t.co, twitter.com or x.com, use the actual website instead (Twitter/X handles belong in the "twitter" field))], website_errors("http://t.co/VKiTe81rKb")
  end

  test "flags twitter.com and x.com links, including subdomains" do
    %w[https://twitter.com/janedoe https://www.twitter.com/janedoe https://mobile.twitter.com/janedoe https://x.com/janedoe].each do |website|
      assert_equal 1, website_errors(website).size, "expected #{website} to be flagged"
    end
  end

  test "only flags the offending speaker and points at its website" do
    raw = <<~YAML
      ---
      - name: "Jane Doe"
        slug: "jane-doe"
        website: "https://janedoe.dev"

      - name: "John Smith"
        slug: "john-smith"
        website: "https://t.co/abc123"
    YAML

    speakers = Static::Speaker.parse(raw).to_a
    jane, john = speakers

    assert jane.valid?
    assert_not john.valid?

    error = john.errors.where(:website).sole
    assert_match(%r{https://t.co/abc123}, error.full_message)
    assert_equal 8, john.error_location(error).start_line
  end

  private

  def website_errors(website)
    speaker = Static::Speaker.parse(%(---\n- name: "Jane Doe"\n  slug: "jane-doe"\n  website: "#{website}"\n)).first
    speaker.valid?

    speaker.errors.full_messages_for(:website)
  end
end
