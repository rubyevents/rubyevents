# frozen_string_literal: true

require "test_helper"

class Static::VideoTest < ActiveSupport::TestCase
  test "kind uses the explicit kind from the YAML when set" do
    video = Static::Video.new("title" => "Keynote: Something", "kind" => "panel")

    assert_equal "panel", video.kind
  end

  test "kind is inferred from the title when not set in the YAML" do
    video = Static::Video.new("title" => "Keynote: Something")

    assert_equal "keynote", video.kind
  end

  test "kind defaults to talk when the title does not classify" do
    video = Static::Video.new("title" => "Building Better APIs")

    assert_equal "talk", video.kind
  end

  test "kind reads an explicit kind from a real videos.yml entry" do
    video = Static::Video.find_by_static_id("drew-bragg-who-wants-to-be-a-ruby-engineer")

    assert_equal "gameshow", video.kind
  end
end
