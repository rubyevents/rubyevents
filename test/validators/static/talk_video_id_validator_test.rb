# frozen_string_literal: true

require "test_helper"

class Static::TalkVideoIdValidatorTest < ActiveSupport::TestCase
  include StaticDataSandbox

  test "does not flag a talk without a recording that uses its id as its video_id" do
    with_talks([talk("jane-doe-testconf-2024", "not_recorded", "jane-doe-testconf-2024")]) do |talks|
      assert_empty video_id_errors(talks)
    end
  end

  test "does not flag recorded talks or talks nested under a recording" do
    nested = [talk("jane-doe-testconf-2024", "parent", "jane-doe-lightning-talk")]

    with_talks([talk("lightning-talks-testconf-2024", "youtube", "abcdefghijk").merge("talks" => nested)]) do |talks|
      assert_equal 2, talks.count
      assert_empty video_id_errors(talks)
    end
  end

  test "flags a talk without a recording that uses another video_id" do
    with_talks([talk("todo-kcruby-2025-06-24", "not_recorded", "unknown-kcruby-meetup-june-2025")]) do |talks|
      assert_equal [%(video_id "unknown-kcruby-meetup-june-2025" should be "todo-kcruby-2025-06-24". A not_recorded talk uses its own id as its video_id. Run `bin/rails validate:fix` to update it.)], video_id_errors(talks)
    end
  end

  test "points at the video_id" do
    with_talks([talk("todo-kcruby-2025-06-24", "not_recorded", "unknown-kcruby-meetup-june-2025")]) do |talks|
      talk = talks.first
      talk.valid?

      assert_equal talk.source_line("video_id"), talk.error_location(talk.errors.where(:video_id).sole).start_line
    end
  end

  test "fix sets the video_id to the talk's id" do
    with_talks([talk("steve-butterworth-lrug-2020-01-13", "not_published", "lrug-2020-01-13-ruby-on-the-big-screen")]) do |talks, path|
      fixes = Yerba::Record.fix_all(talks, only: Static::TalkVideoIdValidator)

      assert_equal [1], fixes.map(&:last)
      assert_equal "steve-butterworth-lrug-2020-01-13", Yerba.parse_file(path).to_a.first["video_id"]
    end
  end

  test "fix runs after the talk id fix, so the video_id follows the renamed id" do
    videos = [talk("wrong", "not_recorded", "something-else").merge("speakers" => ["Jane Doe"], "title" => "Building Things")]

    with_talks(videos) do |talks, path|
      Static::TalkIdValidator.stub(:baseline_file, nil) do
        Yerba::Record.fix_all(talks, only: [Static::TalkIdValidator, Static::TalkVideoIdValidator])
      end

      fixed = Yerba.parse_file(path).to_a.first

      assert_equal "jane-doe-testconf-2024", fixed["id"]
      assert_equal "jane-doe-testconf-2024", fixed["video_id"]
    end
  end

  private

  def talk(id, video_provider, video_id)
    {"id" => id, "title" => id.titleize, "video_provider" => video_provider, "video_id" => video_id}
  end

  def video_id_errors(talks)
    talks.to_a.flat_map do |talk|
      talk.valid?
      talk.errors.full_messages_for(:video_id)
    end
  end

  def with_talks(videos)
    with_static_data_dir do |root|
      path = File.join(root, "data", "testconf", "testconf-2024", "videos.yml")
      FileUtils.mkdir_p(File.dirname(path))
      Yerba::Document.from(videos).save_to!(path)

      yield Static::Talk.in_file(path), path
    end
  end
end
