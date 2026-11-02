# frozen_string_literal: true

require "test_helper"

class Static::TalkTest < ActiveSupport::TestCase
  test "kind uses the explicit kind from the YAML when set" do
    video = Static::Talk.new("title" => "Keynote: Something", "kind" => "panel")

    assert_equal "panel", video.kind
  end

  test "kind is inferred from the title when not set in the YAML" do
    video = Static::Talk.new("title" => "Keynote: Something")

    assert_equal "keynote", video.kind
  end

  test "kind defaults to talk when the title does not classify" do
    video = Static::Talk.new("title" => "Building Better APIs")

    assert_equal "talk", video.kind
  end

  test "kind reads an explicit kind from a real videos.yml entry" do
    video = Static::Talk.find_by_static_id("drew-bragg-brightonruby-2024")

    assert_equal "gameshow", video.kind
  end

  test "find_or_initialize_talk finds the talk by id" do
    talk = talks(:one)
    video = Static::Talk.new("id" => talk.static_id)

    assert_equal talk, video.find_or_initialize_talk
  end

  test "find_or_initialize_talk falls back to old_id and re-slugs the talk" do
    talk = talks(:one)
    video = Static::Talk.new("id" => "new-id-for-talk", "old_id" => talk.static_id)

    found = video.find_or_initialize_talk

    assert_equal talk, found
    assert_equal "new-id-for-talk", found.static_id
  end

  test "find_or_initialize_talk prefers the new id over old_id" do
    talk = talks(:one)
    other = talks(:two)
    video = Static::Talk.new("id" => talk.static_id, "old_id" => other.static_id)

    assert_equal talk, video.find_or_initialize_talk
  end

  test "find_or_initialize_talk initializes a new talk when neither id matches" do
    video = Static::Talk.new("id" => "brand-new-talk-id", "old_id" => "gone-id")

    found = video.find_or_initialize_talk

    assert found.new_record?
    assert_equal "brand-new-talk-id", found.static_id
  end

  test "import! imports the remaining talks and then raises when one fails to save" do
    invalid = ActiveRecord::RecordInvalid.new(::Talk.new)
    imported = []
    talks = %w[first broken last].map do |id|
      talk = Struct.new(:id, :title, :parent).new(id, id.capitalize)
      talk.define_singleton_method(:import!) { |**| (id == "broken") ? raise(invalid) : (imported << id) && id }
      talk
    end

    Static::Talk.stub(:all, talks) do
      error = assert_raises(Static::ImportError) { Static::Talk.import! }

      assert_match "broken", error.message
    end

    assert_equal %w[first last], imported
  end
end
