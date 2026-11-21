# frozen_string_literal: true

require "test_helper"

class Static::Validators::TalkIdTest < ActiveSupport::TestCase
  include StaticDataSandbox

  test "applicable? returns true for a videos.yml file" do
    with_temp_video([{"id" => "x", "title" => "Something"}]) do |path|
      assert Static::Validators::TalkId.new(file_path: path).applicable?
    end
  end

  test "applicable? returns false for an event.yml file" do
    file = Dir.glob(Rails.root.join("data/**/event.yml")).first

    assert_not Static::Validators::TalkId.new(file_path: file).applicable?
  end

  test "does not flag talks whose ids match the expected ids" do
    videos = [
      {"id" => "jane-doe-testconf-2024", "title" => "Building Things", "speakers" => ["Jane Doe"]},
      {"id" => "jose-garcia-john-smith-testconf-2024", "title" => "Pairing", "speakers" => ["José García", "John Smith"]}
    ]

    with_temp_video(videos) do |path|
      assert_empty Static::Validators::TalkId.new(file_path: path).errors
    end
  end

  test "flags a talk whose id does not match the expected id" do
    videos = [
      {"id" => "jane-doe-somewhere-else", "title" => "Building Things", "speakers" => ["Jane Doe"]}
    ]

    with_temp_video(videos) do |path|
      errors = Static::Validators::TalkId.new(file_path: path).errors

      assert_equal 1, errors.size
      assert_includes message_without_color(errors.first), %(expected id "jane-doe-testconf-2024")
    end
  end

  test "adds the kind after the speakers" do
    videos = [
      {"id" => "jane-doe-keynote-testconf-2024", "title" => "Building Things", "kind" => "keynote", "speakers" => ["Jane Doe"]}
    ]

    with_temp_video(videos) do |path|
      assert_empty Static::Validators::TalkId.new(file_path: path).errors
    end
  end

  test "does not infer the kind from the title" do
    videos = [
      {"id" => "jane-doe-keynote-testconf-2024", "title" => "Opening Keynote", "speakers" => ["Jane Doe"]}
    ]

    with_temp_video(videos) do |path|
      errors = Static::Validators::TalkId.new(file_path: path).errors

      assert_equal 1, errors.size
      assert_includes message_without_color(errors.first), %(expected id "jane-doe-testconf-2024")
    end
  end

  test "uses the kind and title for more than two speakers" do
    videos = [
      {"id" => "keynote-building-things-testconf-2024", "title" => "Building Things", "kind" => "keynote", "speakers" => ["A B", "C D", "E F"]}
    ]

    with_temp_video(videos) do |path|
      assert_empty Static::Validators::TalkId.new(file_path: path).errors
    end
  end

  test "uses the title alone when it contains the kind" do
    videos = [
      {"id" => "opening-keynote-testconf-2024", "title" => "Opening Keynote", "kind" => "keynote"}
    ]

    with_temp_video(videos) do |path|
      assert_empty Static::Validators::TalkId.new(file_path: path).errors
    end
  end

  test "adds the title when talks share a base id" do
    videos = [
      {"id" => "jane-doe-building-things-testconf-2024", "title" => "Building Things", "speakers" => ["Jane Doe"]},
      {"id" => "jane-doe-breaking-things-testconf-2024", "title" => "Breaking Things", "speakers" => ["Jane Doe"]}
    ]

    with_temp_video(videos) do |path|
      assert_empty Static::Validators::TalkId.new(file_path: path).errors
    end
  end

  test "flags shared base ids that are missing the title" do
    videos = [
      {"id" => "jane-doe-testconf-2024", "title" => "Building Things", "speakers" => ["Jane Doe"]},
      {"id" => "jane-doe-testconf-2024", "title" => "Breaking Things", "speakers" => ["Jane Doe"]}
    ]

    with_temp_video(videos) do |path|
      errors = Static::Validators::TalkId.new(file_path: path).errors

      assert_equal 2, errors.size
      assert errors.any? { |error| message_without_color(error).include?(%(expected id "jane-doe-building-things-testconf-2024")) }
      assert errors.any? { |error| message_without_color(error).include?(%(expected id "jane-doe-breaking-things-testconf-2024")) }
    end
  end

  test "numbers ids when the titles collide too" do
    videos = [
      {"id" => "jane-doe-building-things-1-testconf-2024", "title" => "Building Things", "speakers" => ["Jane Doe"]},
      {"id" => "jane-doe-building-things-2-testconf-2024", "title" => "Building Things", "speakers" => ["Jane Doe"]}
    ]

    with_temp_video(videos) do |path|
      assert_empty Static::Validators::TalkId.new(file_path: path).errors
    end
  end

  test "does not repeat the title when it is already part of the base id" do
    videos = [
      {"id" => "opening-keynote-1-testconf-2024", "title" => "Opening Keynote", "kind" => "keynote"},
      {"id" => "opening-keynote-2-testconf-2024", "title" => "Opening Keynote", "kind" => "keynote"}
    ]

    with_temp_video(videos) do |path|
      assert_empty Static::Validators::TalkId.new(file_path: path).errors
    end
  end

  test "does not repeat the kind when the title starts with it" do
    videos = [
      {"id" => "jane-doe-keynote-foo-testconf-2024", "title" => "Keynote: Foo", "kind" => "keynote", "speakers" => ["Jane Doe"]},
      {"id" => "jane-doe-keynote-bar-testconf-2024", "title" => "Keynote: Bar", "kind" => "keynote", "speakers" => ["Jane Doe"]}
    ]

    with_temp_video(videos) do |path|
      assert_empty Static::Validators::TalkId.new(file_path: path).errors
    end
  end

  test "ignores TODO placeholder speakers" do
    videos = [
      {"id" => "building-things-testconf-2024", "title" => "Building Things", "speakers" => ["TODO"]}
    ]

    with_temp_video(videos) do |path|
      assert_empty Static::Validators::TalkId.new(file_path: path).errors
    end
  end

  test "checks nested talks" do
    videos = [
      {
        "id" => "opening-keynote-testconf-2024",
        "title" => "Opening Keynote",
        "kind" => "keynote",
        "talks" => [
          {"id" => "jane-doe-wrong", "title" => "Building Things", "speakers" => ["Jane Doe"]}
        ]
      }
    ]

    with_temp_video(videos) do |path|
      errors = Static::Validators::TalkId.new(file_path: path).errors

      assert_equal 1, errors.size
      assert_includes message_without_color(errors.first), %(expected id "jane-doe-testconf-2024")
    end
  end

  test "old_id does not affect validation" do
    videos = [
      {"id" => "jane-doe-testconf-2024", "old_id" => "jane-doe-somewhere-else", "title" => "Building Things", "speakers" => ["Jane Doe"]}
    ]

    with_temp_video(videos) do |path|
      assert_empty Static::Validators::TalkId.new(file_path: path).errors
    end
  end

  test "adds the title when speakers with different names share a base id" do
    videos = [
      {"id" => "jane-doe-building-things-testconf-2024", "title" => "Building Things", "speakers" => ["Jane Doe"]},
      {"id" => "jane-doe-breaking-things-testconf-2024", "title" => "Breaking Things", "speakers" => ["Jane", "Doe"]}
    ]

    with_temp_video(videos) do |path|
      assert_empty Static::Validators::TalkId.new(file_path: path).errors
    end
  end

  test "checks talks at meetup events against the meetup's slug" do
    videos = [
      {"id" => "some-freeform-meetup-id", "title" => "Building Things", "speakers" => ["Jane Doe"]}
    ]

    with_temp_video(videos, event: {"id" => "testconf-2024", "kind" => "meetup"}) do |path|
      errors = Static::Validators::TalkId.new(file_path: path).errors

      assert_equal 1, errors.size
      assert_includes message_without_color(errors.first), %(expected id "jane-doe-testconf-2024")
    end
  end

  test "adds old_id when fixing an id that was committed in another file" do
    videos = [
      {"id" => "jane-doe-testrb-meetup-january-2024", "title" => "Building Things", "speakers" => ["Jane Doe"]}
    ]

    with_temp_video(videos) do |path|
      Static::Validators::TalkId.stub(:baseline_talk_ids, Set["jane-doe-testrb-meetup-january-2024"]) do
        Static::Validators::TalkId.new(file_path: path).fix
      end

      node = Yerba.parse_file(path).find_by("id" => "jane-doe-testconf-2024")

      assert_equal "jane-doe-testrb-meetup-january-2024", node.value_at("old_id")
    end
  end

  test "moves the thumbnail of a talk cut from a shared recording when fixing its id" do
    videos = [
      {"id" => "wrong", "title" => "Fixing in Validators", "speakers" => ["Rachael Wright-Munn"], "start_cue" => "01:00", "end_cue" => "20:00", "video_provider" => "youtube", "video_id" => "abcdefghijk"}
    ]

    with_temp_video(videos) do |path|
      with_temp_thumbnails(path) do |thumbnails|
        File.write(File.join(thumbnails, "wrong.webp"), "webp")

        Static::Validators::TalkId.new(file_path: path).fix

        assert File.exist?(File.join(thumbnails, "rachael-wright-munn-testconf-2024.webp"))
        assert_not File.exist?(File.join(thumbnails, "wrong.webp"))
        assert_equal "abcdefghijk", Yerba.parse_file(path).find_by("id" => "rachael-wright-munn-testconf-2024").value_at("video_id")
      end
    end
  end

  test "expected_ids maps every talk to the id it should have" do
    videos = [
      {"id" => "wrong", "title" => "Building Things", "speakers" => ["Jane Doe"]}
    ]

    with_temp_video(videos) do |path|
      expected = Static::Validators::TalkId.new(file_path: path).send(:expected_ids)

      assert_equal ["jane-doe-testconf-2024"], expected.values
    end
  end

  test "fixes bad ids by renaming them without old_id when they were never committed" do
    videos = [
      {"id" => "wrong", "title" => "Fixing in Validators", "speakers" => ["Rachael Wright-Munn"]},
      {"id" => "f8-testconf-2024", "title" => "Tharax", "speakers" => ["f8"]}
    ]

    with_temp_video(videos) do |path|
      validator = Static::Validators::TalkId.new(file_path: path)
      validator.fix

      document = Yerba.parse_file(path)
      node = document.find_by("id" => "rachael-wright-munn-testconf-2024")

      assert node
      assert_nil node.value_at("old_id")
    end
  end

  test "adds old_id when fixing an id that was committed" do
    videos = [
      {"id" => "wrong", "title" => "Fixing in Validators", "speakers" => ["Rachael Wright-Munn"]}
    ]
    baseline = [
      {"id" => "wrong", "title" => "Fixing in Validators", "speakers" => ["Rachael Wright-Munn"]}
    ]

    with_temp_video(videos) do |path|
      validator = Static::Validators::TalkId.new(
        file_path: path,
        baseline: Static::Talk.parse(baseline.to_yaml)
      )
      validator.fix

      node = Yerba.parse_file(path).find_by("id" => "rachael-wright-munn-testconf-2024")

      assert_equal "wrong", node.value_at("old_id")
    end
  end

  test "replaces an existing old_id with the committed id when fixing an id" do
    videos = [
      {"id" => "wrong", "old_id" => "some-legacy-id", "title" => "Fixing in Validators", "speakers" => ["Rachael Wright-Munn"]}
    ]
    baseline = [
      {"id" => "wrong", "old_id" => "some-legacy-id", "title" => "Fixing in Validators", "speakers" => ["Rachael Wright-Munn"]}
    ]

    with_temp_video(videos) do |path|
      validator = Static::Validators::TalkId.new(
        file_path: path,
        baseline: Static::Talk.parse(baseline.to_yaml)
      )
      validator.fix

      node = Yerba.parse_file(path).find_by("id" => "rachael-wright-munn-testconf-2024")

      assert_equal "wrong", node.value_at("old_id")
    end
  end

  test "keeps an existing old_id when the current id was never committed" do
    videos = [
      {"id" => "wrong", "old_id" => "some-legacy-id", "title" => "Fixing in Validators", "speakers" => ["Rachael Wright-Munn"]}
    ]

    with_temp_video(videos) do |path|
      Static::Validators::TalkId.stub(:baseline_talk_ids, Set.new) do
        Static::Validators::TalkId.new(file_path: path).fix
      end

      node = Yerba.parse_file(path).find_by("id" => "rachael-wright-munn-testconf-2024")

      assert_equal "some-legacy-id", node.value_at("old_id")
    end
  end

  test "removes old_id when it matches the id the talk is being fixed to" do
    videos = [
      {"id" => "wrong", "old_id" => "rachael-wright-munn-testconf-2024", "title" => "Fixing in Validators", "speakers" => ["Rachael Wright-Munn"]}
    ]
    baseline = [
      {"id" => "other-talk", "title" => "Other", "speakers" => ["Other Person"]}
    ]

    with_temp_video(videos) do |path|
      validator = Static::Validators::TalkId.new(
        file_path: path,
        baseline: Static::Talk.parse(baseline.to_yaml)
      )
      validator.fix

      node = Yerba.parse_file(path).find_by("id" => "rachael-wright-munn-testconf-2024")

      assert_nil node.value_at("old_id")
      assert_not node.to_h.key?("old_id"), "old_id should be removed, not left as null"
    end
  end

  test "fixes the video_id of a non-watchable talk when it matches the renamed id" do
    videos = [
      {
        "id" => "wrong",
        "video_id" => "wrong",
        "video_provider" => "scheduled",
        "title" => "Fixing in Validators",
        "speakers" => ["Rachael Wright-Munn"]
      }
    ]

    with_temp_video(videos) do |path|
      result = Static::Validators::TalkId.new(file_path: path).fix
      node = Yerba.parse_file(path).find_by("id" => "rachael-wright-munn-testconf-2024")

      assert_equal "rachael-wright-munn-testconf-2024", node.value_at("video_id")
      assert_equal({changed: 1, file_path: path}, result)
    end
  end

  test "does not save the file when no ids need fixing" do
    videos = [
      {"id" => "jane-doe-testconf-2024", "title" => "Building Things", "speakers" => ["Jane Doe"]}
    ]

    with_temp_video(videos) do |path|
      validator = Static::Validators::TalkId.new(file_path: path)
      original_content = File.read(path)

      assert_empty validator.errors

      assert_nil validator.fix

      assert_equal original_content, File.read(path), "fix should not write a file it has nothing to fix"
    end
  end

  test "fix does not write files it is not applicable to" do
    file = Dir.glob(Rails.root.join("data/**/event.yml")).first
    original_content = File.read(file)

    assert_nil Static::Validators::TalkId.new(file_path: file).fix

    assert_equal original_content, File.read(file)
  end

  test "renames thumbnail files when fixing an id" do
    videos = [
      {"id" => "wrong", "title" => "Fixing in Validators", "speakers" => ["Rachael Wright-Munn"], "video_provider" => "not_recorded", "video_id" => "wrong"}
    ]

    with_temp_video(videos) do |path|
      with_temp_thumbnails(path) do |thumbnails|
        File.write(File.join(thumbnails, "wrong.webp"), "webp")

        Static::Validators::TalkId.new(file_path: path).fix

        assert File.exist?(File.join(thumbnails, "rachael-wright-munn-testconf-2024.webp"))
        assert_not File.exist?(File.join(thumbnails, "wrong.webp"))
      end
    end
  end

  test "renames a thumbnail directory when fixing an id" do
    videos = [
      {"id" => "wrong", "title" => "Fixing in Validators", "speakers" => ["Rachael Wright-Munn"], "video_provider" => "not_recorded", "video_id" => "wrong"}
    ]

    with_temp_video(videos) do |path|
      with_temp_thumbnails(path) do |thumbnails|
        FileUtils.mkdir_p(File.join(thumbnails, "wrong"))
        File.write(File.join(thumbnails, "wrong", "lightning.webp"), "webp")

        Static::Validators::TalkId.new(file_path: path).fix

        renamed = File.join(thumbnails, "rachael-wright-munn-testconf-2024", "lightning.webp")
        assert File.exist?(renamed)
        assert_not Dir.exist?(File.join(thumbnails, "wrong"))
      end
    end
  end

  test "does not clobber an existing thumbnail or directory when fixing an id" do
    videos = [
      {"id" => "wrong", "title" => "Fixing in Validators", "speakers" => ["Rachael Wright-Munn"], "video_provider" => "not_recorded", "video_id" => "wrong"}
    ]

    with_temp_video(videos) do |path|
      with_temp_thumbnails(path) do |thumbnails|
        File.write(File.join(thumbnails, "wrong.webp"), "new")
        FileUtils.mkdir_p(File.join(thumbnails, "wrong"))
        File.write(File.join(thumbnails, "rachael-wright-munn-testconf-2024.webp"), "keep-file")
        FileUtils.mkdir_p(File.join(thumbnails, "rachael-wright-munn-testconf-2024"))
        File.write(File.join(thumbnails, "rachael-wright-munn-testconf-2024", "talk.webp"), "keep-dir")

        Static::Validators::TalkId.new(file_path: path).fix

        assert_equal "keep-file", File.read(File.join(thumbnails, "rachael-wright-munn-testconf-2024.webp"))
        assert_equal "keep-dir", File.read(File.join(thumbnails, "rachael-wright-munn-testconf-2024", "talk.webp"))
        assert File.exist?(File.join(thumbnails, "wrong.webp")), "a file whose target exists stays behind"
        assert Dir.exist?(File.join(thumbnails, "wrong")), "a directory whose target exists stays behind"
      end
    end
  end

  private

  def message_without_color(error)
    error.message.gsub(/\e\[[\d;]*m/, "")
  end

  def with_temp_video(videos, event: nil)
    with_static_data_dir do |dir|
      videos_path = File.join(dir, "data", "testconf", "testconf-2024", "videos.yml")
      FileUtils.mkdir_p(File.dirname(videos_path))
      File.write(videos_path, videos.to_yaml)
      File.write(File.join(File.dirname(videos_path), "event.yml"), event.to_yaml) if event
      yield videos_path
    end
  end

  def with_temp_thumbnails(videos_path)
    thumbnails = File.join(File.dirname(videos_path, 4), "app", "assets", "images", "thumbnails", "testconf-2024")
    FileUtils.mkdir_p(thumbnails)

    yield thumbnails
  end
end
