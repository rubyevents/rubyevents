# frozen_string_literal: true

require "test_helper"

class Ui::SocialLinksComponentTest < ViewComponent::TestCase
  def test_platforms_returns_entries_for_present_fields
    source = OpenStruct.new(twitter: "railsconf", github: "rails")
    component = Ui::SocialLinksComponent.new(source)

    platforms = component.platforms
    assert_equal %w[github twitter], platforms.map(&:field).sort
  end

  def test_platforms_excludes_blank_fields
    source = OpenStruct.new(twitter: "railsconf", github: "", mastodon: nil)
    component = Ui::SocialLinksComponent.new(source)

    platforms = component.platforms
    assert_equal ["twitter"], platforms.map(&:field)
  end

  def test_platforms_excludes_fields_source_does_not_respond_to
    source = OpenStruct.new(twitter: "railsconf")
    component = Ui::SocialLinksComponent.new(source)

    fields = component.platforms.map(&:field)
    assert_includes fields, "twitter"
    refute_includes fields, "github"
  end

  def test_url_building_for_handle_based_platforms
    source = OpenStruct.new(
      twitter: "railsconf",
      github: "rails",
      bsky: "railsconf.bsky.social",
      linkedin: "railsconf"
    )
    component = Ui::SocialLinksComponent.new(source)

    urls = component.platforms.each_with_object({}) { |p, h| h[p.field] = p.url }
    assert_equal "https://x.com/railsconf", urls["twitter"]
    assert_equal "https://github.com/rails", urls["github"]
    assert_equal "https://bsky.app/profile/railsconf.bsky.social", urls["bsky"]
    assert_equal "https://www.linkedin.com/in/railsconf", urls["linkedin"]
  end

  def test_url_building_for_url_based_platforms
    source = OpenStruct.new(
      mastodon: "https://ruby.social/@railsconf",
      meetup: "https://www.meetup.com/railsconf",
      luma: "https://lu.ma/railsconf",
      facebook: "https://facebook.com/railsconf"
    )
    component = Ui::SocialLinksComponent.new(source)

    urls = component.platforms.each_with_object({}) { |p, h| h[p.field] = p.url }
    assert_equal "https://ruby.social/@railsconf", urls["mastodon"]
    assert_equal "https://www.meetup.com/railsconf", urls["meetup"]
    assert_equal "https://lu.ma/railsconf", urls["luma"]
    assert_equal "https://facebook.com/railsconf", urls["facebook"]
  end

  # Rendering tests

  def test_renders_links_with_correct_hrefs
    source = OpenStruct.new(twitter: "railsconf", github: "rails")
    render_inline(Ui::SocialLinksComponent.new(source))

    assert_selector("a[href='https://x.com/railsconf'][target='_blank']")
    assert_selector("a[href='https://github.com/rails'][target='_blank']")
  end

  def test_inline_variant_renders_inline_styles
    source = OpenStruct.new(twitter: "railsconf")
    render_inline(Ui::SocialLinksComponent.new(source, variant: :inline))

    assert_selector("a.inline-flex")
  end

  def test_circle_variant_renders_button_styles
    source = OpenStruct.new(twitter: "railsconf")
    render_inline(Ui::SocialLinksComponent.new(source, variant: :circle))

    refute_selector("a.inline-flex")
  end

  def test_renders_nothing_when_no_social_fields_present
    source = OpenStruct.new(twitter: "", github: nil)
    render_inline(Ui::SocialLinksComponent.new(source))

    assert_no_selector("a")
  end
end
