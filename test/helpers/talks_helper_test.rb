# frozen_string_literal: true

require "test_helper"

class TalksHelperTest < ActionView::TestCase
  test "google_slides_embed_url converts edit URL to embed URL" do
    url = "https://docs.google.com/presentation/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgVE2upms/edit"
    assert_equal "https://docs.google.com/presentation/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgVE2upms/embed",
      google_slides_embed_url(url)
  end

  test "google_slides_embed_url converts view URL to embed URL" do
    url = "https://docs.google.com/presentation/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgVE2upms/view"
    assert_equal "https://docs.google.com/presentation/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgVE2upms/embed",
      google_slides_embed_url(url)
  end

  test "google_slides_embed_url converts published URL to embed URL" do
    url = "https://docs.google.com/presentation/d/e/2PACX-1vSomePublishedId/pub"
    assert_equal "https://docs.google.com/presentation/d/e/2PACX-1vSomePublishedId/embed",
      google_slides_embed_url(url)
  end

  test "google_slides_embed_url handles bare presentation ID without action segment" do
    url = "https://docs.google.com/presentation/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgVE2upms"
    assert_equal "https://docs.google.com/presentation/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgVE2upms/embed",
      google_slides_embed_url(url)
  end

  test "google_slides_embed_url is idempotent on already-embed URL" do
    url = "https://docs.google.com/presentation/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgVE2upms/embed"
    assert_equal url, google_slides_embed_url(url)
  end

  test "google_slides_embed_url strips query string" do
    url = "https://docs.google.com/presentation/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgVE2upms/edit?usp=sharing"
    assert_equal "https://docs.google.com/presentation/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgVE2upms/embed",
      google_slides_embed_url(url)
  end

  test "google_slides_embed_url strips URL fragment" do
    url = "https://docs.google.com/presentation/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgVE2upms/edit#slide=id.p"
    assert_equal "https://docs.google.com/presentation/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgVE2upms/embed",
      google_slides_embed_url(url)
  end

  test "google_slides_embed_url returns nil for nil input" do
    assert_nil google_slides_embed_url(nil)
  end

  test "google_slides_embed_url returns nil for non-Google URLs" do
    assert_nil google_slides_embed_url("https://speakerdeck.com/someone/talk")
  end

  test "google_slides_embed_url returns nil for other Google Docs types" do
    assert_nil google_slides_embed_url("https://docs.google.com/document/d/someDocId/edit")
  end

  test "google_slides_embed_url returns nil for invalid URLs" do
    assert_nil google_slides_embed_url("not a url")
  end
end
