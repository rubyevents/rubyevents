require "test_helper"
require "generators/talk/talk_generator"
require "#{Rails.root}/app/schemas/video_schema"
require "json_schemer"

class TalkGeneratorTest < Rails::Generators::TestCase
  tests TalkGenerator
  destination Rails.root.join("tmp/generators")
  setup :prepare_destination

  test "generator runs without errors" do
    assert_nothing_raised do
      run_generator ["--event-series", "rubyconf", "--event", "2024"]
    end
  end

  test "creates talks.yml with valid yaml" do
    run_generator ["--event-series", "rubyconf", "--event", "2024"]

    assert_file "data/rubyconf/2024/videos.yml" do |content|
      assert_match(/\S/, content)
    end

    talk_file_path = File.join(destination_root, "data/rubyconf/2024/videos.yml")
    validate_talk_file(talk_file_path)
  end

  test "update talks.yml if called twice" do
    run_generator ["--event-series", "rubyconf", "--event", "2024", "--title", "Keynote: Jane Doe", "--speaker", "Jane Doe"]
    run_generator ["--event-series", "rubyconf", "--event", "2024", "--title", "Keynote: Talks about Talks", "--speaker", "Jane Doe"]

    assert_file "data/rubyconf/2024/videos.yml" do |content|
      assert_match(%r{title: "Keynote: Jane Doe"}, content)
      assert_no_match(%r{title: "Keynote: Talks about Talks"}, content)
    end

    talk_file_path = File.join(destination_root, "data/rubyconf/2024/videos.yml")
    validate_talk_file(talk_file_path)
  end

  test "append to talks.yml if called with a different details" do
    run_generator ["--event-series", "rubyconf", "--event", "2024", "--title", "Keynote: Jane Doe", "--speaker", "Jane Doe"]
    run_generator ["--event-series", "rubyconf", "--event", "2024", "--title", "RubyEvents is great", "--speaker", "Rachael Wright-Munn"]

    assert_file "data/rubyconf/2024/videos.yml" do |content|
      assert_match(/Keynote/, content)
      assert_match(/Talk TWO/, content)
    end

    talk_file_path = File.join(destination_root, "data/rubyconf/2024/videos.yml")
    validate_talk_file(talk_file_path)
  end

  def validate_talk_file(path)
    data = YAML.load_file(path)
    schema = JSON.parse(VideoSchema.new.to_json_schema[:schema].to_json)
    schemer = JSONSchemer.schema(schema)

    errors = []
    Array(data).each_with_index do |item, index|
      errs = schemer.validate(item).to_a
      errors.append(errs) unless errs.empty?
    end

    assert_empty errors, "Talks YAML does not conform to schema: #{errors.join(", ")}"
  end
end
