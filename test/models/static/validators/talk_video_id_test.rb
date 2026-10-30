# frozen_string_literal: true

require "test_helper"

class Static::Validators::TalkVideoIdTest < ActiveSupport::TestCase
  include StaticDataSandbox

  test "does not flag a talk without a recording that uses its id as its video_id" do
    with_temp_video([talk("jane-doe-testconf-2024", "not_recorded", "jane-doe-testconf-2024")]) do |path|
      assert_empty Static::Validators::TalkVideoId.new(file_path: path).errors
    end
  end

  test "does not flag recorded talks or talks nested under a recording" do
    nested = [talk("jane-doe-testconf-2024", "parent", "jane-doe-lightning-talk")]

    with_temp_video([talk("lightning-talks-testconf-2024", "youtube", "abcdefghijk").merge("talks" => nested)]) do |path|
      assert_empty Static::Validators::TalkVideoId.new(file_path: path).errors
    end
  end

  test "flags a talk without a recording that uses another video_id" do
    with_temp_video([talk("todo-kcruby-2025-06-24", "not_recorded", "unknown-kcruby-meetup-june-2025")]) do |path|
      errors = Static::Validators::TalkVideoId.new(file_path: path).errors

      assert_equal [%(video_id "unknown-kcruby-meetup-june-2025" should be "todo-kcruby-2025-06-24". A not_recorded talk uses its own id as its video_id. Run `bin/rails validate:fix` to update it.)], errors.map(&:message)
    end
  end

  test "fix sets the video_id to the talk's id" do
    with_temp_video([talk("steve-butterworth-lrug-2020-01-13", "not_published", "lrug-2020-01-13-ruby-on-the-big-screen")]) do |path|
      assert_equal({changed: 1, file_path: path}, Static::Validators::TalkVideoId.new(file_path: path).fix)
      assert_equal "steve-butterworth-lrug-2020-01-13", Yerba.parse_file(path).to_a.first["video_id"]
    end
  end

  private

  def talk(id, video_provider, video_id)
    {"id" => id, "title" => id.titleize, "video_provider" => video_provider, "video_id" => video_id}
  end

  def with_temp_video(videos)
    with_static_data_dir do |root|
      path = File.join(root, "data", "testconf", "testconf-2024", "videos.yml")
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, Yerba::Document.from(videos).to_s)

      yield path
    end
  end
end
