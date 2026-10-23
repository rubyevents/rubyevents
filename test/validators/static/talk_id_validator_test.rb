# frozen_string_literal: true

require "test_helper"

class Static::TalkIdValidatorTest < ActiveSupport::TestCase
  include StaticDataSandbox

  test "does not flag a single speaker talk with a matching id" do
    assert_no_id_errors [{"id" => "jane-doe-testconf-2024", "title" => "Building Things", "speakers" => ["Jane Doe"]}]
  end

  test "flags a talk whose id does not match firstname-lastname-event-slug" do
    errors = id_errors([{"id" => "jane-doe-somewhere-else", "title" => "Building Things", "speakers" => ["Jane Doe"]}])

    assert_equal ["jane-doe-somewhere-else"], errors.keys
    assert_equal [%(id "jane-doe-somewhere-else" does not match the expected id "jane-doe-testconf-2024". Talk ids should be "firstname-lastname-testconf-2024", with the kind added on duplicates, the kind alone for talks without one or two speakers, and the title in slug form as a last resort. Run `bin/rails validate:fix` to rename it and keep the current id as old_id.)], errors.values.first
  end

  test "points at the id" do
    raw = <<~YAML
      ---
      - title: "Building Things"
        id: "wrong"
        speakers:
          - "Jane Doe"
    YAML

    with_talks(raw) do |talks|
      talk = talks.find_by(id: "wrong")
      talk.valid?(:lint)

      assert_equal 3, talk.error_location(talk.errors.where(:id).first).start_line
    end
  end

  test "parameterizes accented speaker names" do
    assert_no_id_errors [{"id" => "jose-garcia-testconf-2024", "title" => "Hola", "speakers" => ["José García"]}]
  end

  test "joins two speakers in the id" do
    assert_no_id_errors [{"id" => "jane-doe-john-smith-testconf-2024", "title" => "Pairing", "speakers" => ["Jane Doe", "John Smith"]}]
  end

  test "adds the kind when the same speaker would get a duplicate id" do
    assert_no_id_errors [
      {"id" => "jane-doe-testconf-2024", "title" => "Building Things", "speakers" => ["Jane Doe"]},
      {"id" => "jane-doe-lightning-talk-testconf-2024", "title" => "Lightning Talk: Tiny Things", "speakers" => ["Jane Doe"]}
    ]
  end

  test "flags a duplicate that is missing the kind" do
    errors = id_errors([
      {"id" => "jane-doe-testconf-2024", "title" => "Building Things", "speakers" => ["Jane Doe"]},
      {"id" => "jane-doe-2-testconf-2024", "title" => "Keynote: Big Things", "speakers" => ["Jane Doe"]}
    ])

    assert_equal ["jane-doe-2-testconf-2024"], errors.keys
    assert_includes errors.values.first.sole, %(expected id "jane-doe-keynote-testconf-2024")
  end

  test "falls back to the title when speaker and kind still collide" do
    errors = id_errors([
      {"id" => "jane-doe-building-things-testconf-2024", "title" => "Building Things", "speakers" => ["Jane Doe"]},
      {"id" => "jane-doe-breaking-things-testconf-2024", "title" => "Breaking Things", "speakers" => ["Jane Doe"]}
    ])

    assert_includes errors["jane-doe-building-things-testconf-2024"].sole, %(expected id "building-things-testconf-2024")
    assert_includes errors["jane-doe-breaking-things-testconf-2024"].sole, %(expected id "breaking-things-testconf-2024")
  end

  test "numbers ids when speakers, kind and title all collide" do
    assert_no_id_errors [
      {"id" => "building-things-1-testconf-2024", "title" => "Building Things", "speakers" => ["Jane Doe"]},
      {"id" => "building-things-2-testconf-2024", "title" => "Building Things", "speakers" => ["Jane Doe"]}
    ]
  end

  test "uses the kind for talks with more than two speakers" do
    assert_no_id_errors [{"id" => "panel-testconf-2024", "title" => "Panel: The Future of Ruby", "kind" => "panel", "speakers" => ["A B", "C D", "E F"]}]
  end

  test "uses the title when multiple speakerless talks share the kind" do
    assert_no_id_errors [
      {"id" => "panel-on-testing-testconf-2024", "title" => "Panel on Testing", "kind" => "panel", "speakers" => ["A B", "C D", "E F"]},
      {"id" => "panel-on-hiring-testconf-2024", "title" => "Panel on Hiring", "kind" => "panel", "speakers" => ["G H", "I J", "K L"]}
    ]
  end

  test "ignores TODO placeholder speakers and falls back to the title" do
    assert_no_id_errors [{"id" => "building-things-testconf-2024", "title" => "Building Things", "speakers" => ["TODO"]}]
  end

  test "checks nested talks" do
    errors = id_errors([
      {
        "id" => "lightning-talk-testconf-2024",
        "title" => "Lightning Talks",
        "kind" => "lightning_talk",
        "talks" => [
          {"id" => "jane-doe-wrong", "title" => "Lightning Talk: Tiny Things", "speakers" => ["Jane Doe"]}
        ]
      }
    ])

    assert_equal ["jane-doe-wrong"], errors.keys
    assert_includes errors["jane-doe-wrong"].sole, %(expected id "jane-doe-testconf-2024")
  end

  test "old_id does not affect validation" do
    assert_no_id_errors [{"id" => "jane-doe-testconf-2024", "old_id" => "jane-doe-somewhere-else", "title" => "Building Things", "speakers" => ["Jane Doe"]}]
  end

  test "does not expect an id that is reserved as another talk's old_id" do
    assert_no_id_errors [
      {"id" => "jane-doe-lightning-talk-testconf-2024", "old_id" => "jane-doe-testconf-2024", "title" => "Lightning Talk: Tiny Things", "speakers" => ["Jane Doe"]},
      {"id" => "building-things-testconf-2024", "old_id" => "jane-doe-building-things", "title" => "Building Things", "speakers" => ["Jane Doe"]}
    ]
  end

  test "ignores talks at meetup events" do
    assert_no_id_errors [{"id" => "some-freeform-meetup-id", "title" => "Building Things", "speakers" => ["Jane Doe"]}], event: {"kind" => "meetup"}
  end

  test "fixes bad ids by renaming them without old_id when they were never committed" do
    videos = [
      {"id" => "wrong", "title" => "Fixing in Validators", "speakers" => ["Rachael Wright-Munn"]},
      {"id" => "f8-testconf-2024", "title" => "Tharax", "speakers" => ["f8"]}
    ]

    with_talks(videos) do |_talks, path|
      fix(path)

      talk = Static::Talk.in_file(path).find_by(id: "rachael-wright-munn-testconf-2024")
      assert talk
      assert_not talk.key?("old_id")
      assert Static::Talk.in_file(path).find_by(id: "f8-testconf-2024")
    end
  end

  test "adds old_id when fixing an id that was committed" do
    videos = [{"id" => "wrong", "title" => "Fixing in Validators", "speakers" => ["Rachael Wright-Munn"]}]

    with_talks(videos) do |_talks, path|
      with_baseline(%(---\n- id: "wrong"\n  title: "Fixing in Validators"\n)) { fix(path) }

      assert_equal "wrong", Static::Talk.in_file(path).find_by(id: "rachael-wright-munn-testconf-2024")["old_id"]
    end
  end

  test "keeps an existing old_id when fixing an id" do
    videos = [{"id" => "wrong", "old_id" => "some-legacy-id", "title" => "Fixing in Validators", "speakers" => ["Rachael Wright-Munn"]}]

    with_talks(videos) do |_talks, path|
      with_baseline(%(---\n- id: "wrong"\n  old_id: "some-legacy-id"\n)) { fix(path) }

      assert_equal "some-legacy-id", Static::Talk.in_file(path).find_by(id: "rachael-wright-munn-testconf-2024")["old_id"]
    end
  end

  test "removes old_id when it matches the id the talk is being fixed to" do
    videos = [{"id" => "wrong", "old_id" => "rachael-wright-munn-testconf-2024", "title" => "Fixing in Validators", "speakers" => ["Rachael Wright-Munn"]}]

    with_talks(videos) do |_talks, path|
      with_baseline(%(---\n- id: "other-talk"\n)) { fix(path) }

      talk = Static::Talk.in_file(path).find_by(id: "rachael-wright-munn-testconf-2024")
      assert_not talk.key?("old_id"), "old_id should be removed, not left as null"
      assert_not_includes File.read(path), "old_id"
    end
  end

  test "fixes the video_id of a non-watchable talk when it matches the renamed id" do
    videos = [{"id" => "wrong", "video_id" => "wrong", "video_provider" => "scheduled", "title" => "Fixing in Validators", "speakers" => ["Rachael Wright-Munn"]}]

    with_talks(videos) do |_talks, path|
      fixes = fix(path)

      assert_equal [["rachael-wright-munn-testconf-2024", 1]], fixes.map { |record, _validator, changes| [record.id, changes] }
      assert_equal "rachael-wright-munn-testconf-2024", Static::Talk.in_file(path).find_by(id: "rachael-wright-munn-testconf-2024").video_id
    end
  end

  test "does not save the file when no ids need fixing" do
    videos = [{"id" => "jane-doe-testconf-2024", "title" => "Building Things", "speakers" => ["Jane Doe"]}]

    with_talks(videos) do |_talks, path|
      original_content = File.read(path)

      assert_empty fix(path)
      assert_equal original_content, File.read(path), "fix should not write a file it has nothing to fix"
    end
  end

  test "renames thumbnail files when fixing an id" do
    with_talks(thumbnail_videos) do |_talks, path, root|
      thumbnails = thumbnails_dir(root)
      File.write(File.join(thumbnails, "wrong.webp"), "webp")

      fix(path)

      assert File.exist?(File.join(thumbnails, "rachael-wright-munn-testconf-2024.webp"))
      assert_not File.exist?(File.join(thumbnails, "wrong.webp"))
    end
  end

  test "renames a thumbnail directory when fixing an id" do
    with_talks(thumbnail_videos) do |_talks, path, root|
      thumbnails = thumbnails_dir(root)
      FileUtils.mkdir_p(File.join(thumbnails, "wrong"))
      File.write(File.join(thumbnails, "wrong", "lightning.webp"), "webp")

      fix(path)

      assert File.exist?(File.join(thumbnails, "rachael-wright-munn-testconf-2024", "lightning.webp"))
      assert_not Dir.exist?(File.join(thumbnails, "wrong"))
    end
  end

  test "does not clobber an existing thumbnail or directory when fixing an id" do
    with_talks(thumbnail_videos) do |_talks, path, root|
      thumbnails = thumbnails_dir(root)
      File.write(File.join(thumbnails, "wrong.webp"), "new")
      FileUtils.mkdir_p(File.join(thumbnails, "wrong"))
      File.write(File.join(thumbnails, "rachael-wright-munn-testconf-2024.webp"), "keep-file")
      FileUtils.mkdir_p(File.join(thumbnails, "rachael-wright-munn-testconf-2024"))
      File.write(File.join(thumbnails, "rachael-wright-munn-testconf-2024", "talk.webp"), "keep-dir")

      fix(path)

      assert_equal "keep-file", File.read(File.join(thumbnails, "rachael-wright-munn-testconf-2024.webp"))
      assert_equal "keep-dir", File.read(File.join(thumbnails, "rachael-wright-munn-testconf-2024", "talk.webp"))
      assert File.exist?(File.join(thumbnails, "wrong.webp")), "a file whose target exists stays behind"
      assert Dir.exist?(File.join(thumbnails, "wrong")), "a directory whose target exists stays behind"
    end
  end

  private

  def assert_no_id_errors(videos, event: nil)
    assert_empty id_errors(videos, event: event)
  end

  # {talk id => id error messages}, for the talks with id errors
  def id_errors(videos, event: nil)
    with_talks(videos, event: event) do |talks|
      talks.to_a.to_h { |talk|
        talk.valid?(:lint)

        [talk.id, talk.errors.full_messages_for(:id)]
      }.reject { |_id, messages| messages.empty? }
    end
  end

  def fix(path)
    Yerba::Record.fix_all(Static::Talk.in_file(path), only: Static::TalkIdValidator)
  end

  def with_baseline(yaml, &block)
    Static::TalkIdValidator.stub(:baseline_file, ->(_path) { Yerba.parse(yaml) }, &block)
  end

  def thumbnail_videos
    [{"id" => "wrong", "title" => "Fixing in Validators", "speakers" => ["Rachael Wright-Munn"], "video_provider" => "not_recorded", "video_id" => "wrong"}]
  end

  def thumbnails_dir(root)
    File.join(root, "app", "assets", "images", "thumbnails", "testconf-2024").tap { |dir| FileUtils.mkdir_p(dir) }
  end

  def with_talks(videos, event: nil)
    with_static_data_dir do |root|
      path = File.join(root, "data", "testconf", "testconf-2024", "videos.yml")
      FileUtils.mkdir_p(File.dirname(path))
      videos.is_a?(String) ? File.write(path, videos) : Yerba::Document.from(videos).save_to!(path)
      Yerba::Document.from(event).save_to!(File.join(File.dirname(path), "event.yml")) if event

      yield Static::Talk.in_file(path), path, root
    end
  end
end
