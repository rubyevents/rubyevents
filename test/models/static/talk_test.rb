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

  test "is invalid when the title infers a non-default kind that isn't set" do
    talk = Static::Talk.new("title" => "Keynote: The Future", "video_provider" => "not_recorded")

    assert_not talk.valid?
    assert_match(/\Akind is inferred as "keynote" from the title/, talk.errors.full_messages.first)
  end

  test "is valid with an explicit kind, even one that disagrees with the title" do
    assert Static::Talk.new("title" => "Keynote: The Future", "kind" => "keynote", "speakers" => ["Jane Doe"]).valid?
    assert Static::Talk.new("title" => "Keynote: The Future", "kind" => "talk", "speakers" => ["Jane Doe"]).valid?
    assert Static::Talk.new("title" => "I love Ruby", "speakers" => ["Jane Doe"]).valid?
  end

  test "is invalid with a redundant kind: talk, unless the talk is short" do
    talk = Static::Talk.new("title" => "I love Ruby", "kind" => "talk", "speakers" => ["Jane Doe"])

    assert_not talk.valid?
    assert_match(/redundant/, talk.errors.full_messages.first)
    assert Static::Talk.new("title" => "I love Ruby", "kind" => "talk", "start_cue" => "00:00", "end_cue" => "05:00", "speakers" => ["Jane Doe"]).valid?
  end

  test "checks the kind of nested talks" do
    videos = [{"id" => "lightning-talks", "title" => "Lightning Talks", "kind" => "lightning_talk", "video_provider" => "children", "talks" => [{"id" => "foo", "title" => "Lightning Talk: Foo"}]}]

    with_temp_videos(videos) do |talks|
      nested = talks.find_by(id: "foo")

      assert_not nested.valid?
      assert_match(/inferred as "lightning_talk"/, nested.errors.full_messages.first)
    end
  end

  test "id and old_id must be unique across all talks when linting" do
    talk = Static::Talk.new("id" => "new-talk", "old_id" => "drew-bragg-brightonruby-2024", "title" => "A talk", "speakers" => ["Jane Doe"])

    assert talk.valid?
    assert_not talk.valid?(:lint)
    assert_match(%r{\Aold_id "drew-bragg-brightonruby-2024" is not unique, it is also used at data/brightonruby/}, talk.errors.full_messages_for(:old_id).first)
  end

  test "a nested talk with a speaker and start_cue needs an extracted thumbnail when linting" do
    videos = [{"id" => "parent", "title" => "Meta", "kind" => "lightning_talk", "video_id" => "PARENT", "talks" => [{"id" => "jane-doe", "title" => "Lightning Talk: Hi", "kind" => "lightning_talk", "video_id" => "jane-doe", "start_cue" => "01:00", "speakers" => ["Jane Doe"]}]}]

    with_temp_videos(videos) do |talks, root|
      talk = talks.find_by(id: "jane-doe")

      talk.valid?(:lint)
      assert_includes talk.errors.full_messages_for(:thumbnail), %(thumbnail missing thumbnail for talk "jane-doe" at app/assets/images/thumbnails/testconf-2024/parent/jane-doe.webp. Run `bin/rails extract_thumbnails` to generate it.)

      thumbnail = File.join(root, "app/assets/images/thumbnails/testconf-2024/parent/jane-doe.webp")
      FileUtils.mkdir_p(File.dirname(thumbnail))
      FileUtils.touch(thumbnail)

      talk = talks.find_by(id: "jane-doe")
      talk.valid?(:lint)

      assert_empty talk.errors.full_messages_for(:thumbnail)
    end
  end

  test "talks without speakers or a start_cue don't need an extracted thumbnail" do
    videos = [{"id" => "parent", "title" => "Meta", "kind" => "lightning_talk", "talks" => [
      {"id" => "open-mic", "title" => "Lightning Talk: Open Mic", "kind" => "lightning_talk", "video_id" => "open-mic", "start_cue" => "01:00", "speakers" => []},
      {"id" => "todo", "title" => "Lightning Talk: Todo", "kind" => "lightning_talk", "video_id" => "todo", "start_cue" => "TODO", "speakers" => ["Jane Doe"]}
    ]}]

    with_temp_videos(videos) do |talks|
      %w[open-mic todo].each do |id|
        talk = talks.find_by(id: id)
        talk.valid?(:lint)

        assert_empty talk.errors.full_messages_for(:thumbnail)
      end
    end
  end

  ["not_recorded", "scheduled", "not_published", "children", "parent"].each do |provider|
    test "published_at must not be set when video_provider is #{provider}" do
      talk = Static::Talk.new("title" => "A talk", "speakers" => ["Jane Doe"], "video_provider" => provider, "published_at" => "2024-01-15")

      assert_not talk.valid?
      assert_equal [%(published_at (2024-01-15) must not be set when video_provider is "#{provider}")], talk.errors.full_messages
    end

    test "published_at can be absent when video_provider is #{provider}" do
      assert Static::Talk.new("title" => "A talk", "speakers" => ["Jane Doe"], "video_provider" => provider).valid?
    end
  end

  test "published_at is allowed for a watchable provider" do
    assert Static::Talk.new("title" => "A talk", "speakers" => ["Jane Doe"], "video_provider" => "youtube", "published_at" => "2024-01-15T09:00:00Z").valid?
  end

  test "checks the published_at of nested talks" do
    videos = [{"id" => "container", "title" => "Container", "video_provider" => "children", "talks" => [{"id" => "nested", "title" => "Nested", "speakers" => ["Jane Doe"], "video_provider" => "not_recorded", "published_at" => "2024-01-15"}]}]

    with_temp_videos(videos) do |talks|
      nested = talks.find_by(id: "nested")

      assert_not nested.valid?
      assert_equal [%(published_at (2024-01-15) must not be set when video_provider is "not_recorded")], nested.errors.full_messages
    end
  end

  private

  def with_temp_videos(videos)
    root = Dir.mktmpdir
    path = File.join(root, "data", "testconf", "testconf-2024", "videos.yml")
    FileUtils.mkdir_p(File.dirname(path))
    Yerba::Document.from(videos).save_to!(path)

    yield Static::Talk.in_file(path), root
  ensure
    FileUtils.rm_rf(root)
  end
end
