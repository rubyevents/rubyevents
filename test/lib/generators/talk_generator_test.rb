require "test_helper"
require "generators/talk/talk_generator"
require "#{Rails.root}/app/schemas/video_schema"

class TalkGeneratorTest < Rails::Generators::TestCase
  tests TalkGenerator
  destination Rails.root.join("tmp/generators/talk")

  test "generator runs without errors" do
    assert_nothing_raised do
      # This must be a real event - tests Static::Event lookup
      run_generator ["--event", "rubyconf-2024"]
    end

    File.delete(File.join(destination_root, "data/rubyconf/rubyconf-2024/videos.yml"))
  end

  test "creates videos.yml with valid yaml" do
    run_generator ["--event-series", "rubyconf", "--event", "2025"]

    assert_file "data/rubyconf/2025/videos.yml" do |content|
      assert_match(/\S/, content)
    end

    videos_file_path = File.join(destination_root, "data/rubyconf/2025/videos.yml")
    validate_talk_file(videos_file_path)

    File.delete(videos_file_path)
  end

  test "update videos.yml if called twice" do
    run_generator ["--event-series", "rubyconf", "--event", "2026", "--title", "Keynote: Jane Doe", "--speakers", "Jane Doe"]
    run_generator ["--event-series", "rubyconf", "--event", "2026", "--title", "Keynote: Talks about Talks", "--speakers", "Jane Doe"]

    assert_file "data/rubyconf/2026/videos.yml" do |content|
      assert_no_match(%r{title: "Keynote: Jane Doe"}, content)
      assert_match(%r{title: "Keynote: Talks about Talks"}, content)
    end

    videos_file_path = File.join(destination_root, "data/rubyconf/2026/videos.yml")
    validate_talk_file(videos_file_path)

    File.delete(videos_file_path)
  end

  test "append to videos.yml if called with a different details" do
    run_generator ["--event-series", "rubyconf", "--event", "2027", "--title", "Keynote: Jane Doe", "--speakers", "Jane Doe", "--kind", "keynote"]
    run_generator ["--event-series", "rubyconf", "--event", "2027", "--title", "RubyEvents is great", "--speakers", "Rachael Wright-Munn", "Marco Roth"]
    run_generator ["--event-series", "rubyconf", "--event", "2027", "--title", "Future of Ruby Panel", "--kind", "panel", "--speakers", "Rachael Wright-Munn", "Marco Roth", "Jane Doe", "Another Speaker"]

    assert_file "data/rubyconf/2027/videos.yml" do |content|
      assert_match(/Keynote: Jane Doe/, content)
      assert_match(/id: "jane-doe-keynote-2027"/, content)
      assert_match(/RubyEvents is great/, content)
      assert_match(/- Jane Doe/, content)
      assert_match(/- Rachael Wright-Munn/, content)
      assert_match(/- Marco Roth/, content)
      assert_match(/Future of Ruby Panel/, content)
      assert_match(/id: "future-of-ruby-panel-2027"/, content)
    end

    videos_file_path = File.join(destination_root, "data/rubyconf/2027/videos.yml")
    validate_talk_file(videos_file_path)

    File.delete(videos_file_path)
  end

  test "finds event series from static event if not provided" do
    run_generator ["--event", "tropical-on-rails-2026", "--title", "Keynote: Marco Roth", "--speakers", "Marco Roth"]

    assert_file "data/tropicalrb/tropical-on-rails-2026/videos.yml" do |content|
      assert_match(/\S/, content)
    end

    File.delete(File.join(destination_root, "data/tropicalrb/tropical-on-rails-2026/videos.yml"))
  end

  test "creates lightning talk entry when lightning_talks option is true" do
    run_generator ["--event-series", "rubyconf", "--event", "2028", "--title", "Lightning Round", "--description", "Quick talks", "--language", "en", "--lightning-talks"]

    assert_file "data/rubyconf/2028/videos.yml" do |content|
      assert_match(/kind: "lightning_talk"/, content)
      assert_match(/title: "Lightning Round"/, content)
      assert_match(/description: |-\n\sLightning talks\./, content)
      assert_match(/language: "en"/, content)
      assert_match(/talks: \[\]/, content)
    end

    videos_file_path = File.join(destination_root, "data/rubyconf/2028/videos.yml")
    validate_talk_file(videos_file_path)
    File.delete(videos_file_path)
  end

  def validate_talk_file(path)
    errors = Static::Validators::SchemaArray.new(file_path: path).validate
    assert_empty errors, "Videos YAML does not conform to schema: #{errors.join(", ")}"
  end
end
