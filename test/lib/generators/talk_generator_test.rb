require "test_helper"
require "generators/talk/talk_generator"
require "#{Rails.root}/app/schemas/video_schema"

class TalkGeneratorTest < Rails::Generators::TestCase
  tests TalkGenerator
  destination Rails.root.join("tmp/generators/talk")

  test "creates minimum videos.yml with valid yaml" do
    videos_file_path = File.join(destination_root, "data/rubyconf/2024/videos.yml")
    eliminate_validated_file(file_path: videos_file_path) do
      run_generator ["--event-series", "rubyconf",
        "--event", "2024"]

      assert_file videos_file_path do |content|
        assert_match(/id: "todo-2024"/, content)
        assert_match(/title: "Talk by TODO"/, content)
        assert_match(/description: "" # TODO/, content)
        assert_no_match(/kind:/, content)
        assert_match(/language: "English"/, content)
      end
    end
  end

  test "creates maximum videos.yml with valid yaml" do
    videos_file_path = File.join(destination_root, "data/rubyconf/2025/videos.yml")
    eliminate_validated_file(file_path: videos_file_path) do
      run_generator ["--event-series", "rubyconf",
        "--event", "2025",
        "--title", "Keynote: Jane Doe",
        "--description", "An insightful talk about Ruby and its future.",
        "--kind", "keynote",
        "--language", "Japanese",
        "--date", "2025-09-15",
        "--speakers", "Jane Doe"]

      assert_file videos_file_path do |content|
        assert_match(/title: "Keynote: Jane Doe"/, content)
        assert_match(/description: |-\n\sAn insightful talk about Ruby and its future\./, content)
        assert_match(/kind: "keynote"/, content)
        assert_match(/language: "Japanese"/, content)
        assert_match(/date: "2025-09-15"/, content)
        assert_match(/- Jane Doe/, content)
      end
    end
  end

  test "infers a non-default kind from the title when --kind is omitted" do
    videos_file_path = File.join(destination_root, "data/rubyconf/2030/videos.yml")

    eliminate_validated_file(file_path: videos_file_path) do
      run_generator ["--event-series", "rubyconf", "--event", "2030", "--title", "Keynote: Jane Doe", "--speakers", "Jane Doe"]

      assert_file videos_file_path do |content|
        assert_match(/title: "Keynote: Jane Doe"/, content)
        assert_match(/kind: "keynote"/, content)
      end
    end
  end

  test "does not write a kind when the title classifies as the default talk" do
    videos_file_path = File.join(destination_root, "data/rubyconf/2031/videos.yml")

    eliminate_validated_file(file_path: videos_file_path) do
      run_generator ["--event-series", "rubyconf", "--event", "2031", "--title", "Building Better APIs", "--speakers", "Jane Doe"]

      assert_file videos_file_path do |content|
        assert_match(/title: "Building Better APIs"/, content)
        assert_no_match(/kind:/, content)
      end
    end
  end

  test "an explicit --kind wins over the title inference" do
    videos_file_path = File.join(destination_root, "data/rubyconf/2032/videos.yml")

    eliminate_validated_file(file_path: videos_file_path) do
      run_generator ["--event-series", "rubyconf", "--event", "2032", "--title", "Keynote: Jane Doe", "--kind", "panel", "--speakers", "Jane Doe"]

      assert_file videos_file_path do |content|
        assert_match(/kind: "panel"/, content)
      end
    end
  end

  test "writes an explicit --kind talk that overrides a non-default classification" do
    videos_file_path = File.join(destination_root, "data/rubyconf/2033/videos.yml")

    eliminate_validated_file(file_path: videos_file_path) do
      run_generator ["--event-series", "rubyconf", "--event", "2033", "--title", "Welcome to Authentication Hell", "--kind", "talk", "--speakers", "Jane Doe"]

      assert_file videos_file_path do |content|
        assert_match(/title: "Welcome to Authentication Hell"/, content)
        assert_match(/kind: "talk"/, content)
      end
    end
  end

  test "update videos.yml if called twice" do
    videos_file_path = File.join(destination_root, "data/rubyconf/2026/videos.yml")
    eliminate_validated_file(file_path: videos_file_path) do
      run_generator ["--event-series", "rubyconf",
        "--event", "2026",
        "--id", "custom-id-jane-doe",
        "--title", "Keynote: Jane Doe",
        "--speakers", "Jane Doe"]
      run_generator ["--event-series", "rubyconf",
        "--event", "2026",
        "--id", "custom-id-jane-doe",
        "--title", "Keynote: Talks about Talks"]

      assert_file videos_file_path do |content|
        assert_no_match(/title: "Keynote: Jane Doe"/, content)
        assert_match(/title: "Keynote: Talks about Talks"/, content)
        assert_match(/id: "custom-id-jane-doe"/, content)
        assert_match(/- Jane Doe/, content)
      end
    end
  end

  test "append to videos.yml if called with a different details" do
    videos_file_path = File.join(destination_root, "data/rubyconf/2027/videos.yml")
    eliminate_validated_file(file_path: videos_file_path) do
      run_generator ["--event-series", "rubyconf", "--event", "2027", "--title", "Keynote: Jane Doe", "--speakers", "Jane Doe", "--kind", "keynote"]
      run_generator ["--event-series", "rubyconf", "--event", "2027", "--title", "RubyEvents is great", "--speakers", "Rachael Wright-Munn", "Marco Roth"]
      run_generator ["--event-series", "rubyconf", "--event", "2027", "--title", "Future of Ruby Panel", "--kind", "panel", "--speakers", "Rachael Wright-Munn", "Marco Roth", "Jane Doe", "Another Speaker"]

      assert_file videos_file_path do |content|
        assert_match(/title: "Keynote: Jane Doe"/, content)
        assert_match(/id: "jane-doe-keynote-2027"/, content)
        assert_match(/title: "RubyEvents is great"/, content)
        assert_match(/- Jane Doe/, content)
        assert_match(/- Rachael Wright-Munn/, content)
        assert_match(/- Marco Roth/, content)
        assert_match(/- Another Speaker/, content)
        assert_match(/title: "Future of Ruby Panel"/, content)
        assert_match(/id: "future-of-ruby-panel-2027"/, content)
      end
    end
  end

  test "finds event series from static event if not provided" do
    videos_file_path = File.join(destination_root, "data/tropicalrb/tropical-on-rails-2026/videos.yml")
    eliminate_validated_file(file_path: videos_file_path) do
      run_generator ["--event", "tropical-on-rails-2026", "--title", "Keynote: Marco Roth", "--speakers", "Marco Roth"]

      assert_file videos_file_path do |content|
        assert_match(/\S/, content)
      end
    end
  end

  test "creates minimum lightning talk entry when lightning_talks option is true" do
    videos_file_path = File.join(destination_root, "data/rubyconf/2028/videos.yml")
    eliminate_validated_file(file_path: videos_file_path) do
      run_generator ["--event-series", "rubyconf",
        "--event", "2028",
        "--lightning-talks"]

      assert_file videos_file_path do |content|
        assert_match(/kind: "lightning_talk"/, content)
        assert_match(/title: "Lightning Talks"/, content)
        assert_match(/description: |-\n\sLightning talks./, content)
        assert_match(/language: "English"/, content)
        assert_match(/talks: \[\]/, content)
      end
    end
  end

  test "creates maximum lightning talk entry when lightning_talks option is true" do
    videos_file_path = File.join(destination_root, "data/rubyconf/2029/videos.yml")
    eliminate_validated_file(file_path: videos_file_path) do
      run_generator ["--event-series", "rubyconf",
        "--event", "2029",
        "--title", "Lightning Round",
        "--description", "Quick talks",
        "--date", "2029-09-15",
        "--language", "English",
        "--lightning-talks"]

      assert_file videos_file_path do |content|
        assert_match(/kind: "lightning_talk"/, content)
        assert_match(/title: "Lightning Round"/, content)
        assert_match(/description: |-\n\sQuick talks/, content)
        assert_match(/language: "English"/, content)
        assert_match(/talks: \[\]/, content)
      end
    end
  end

  def validate_talk_file(path)
    [Static::Validators::SchemaArray, Static::Validators::TalkKind].each do |validator|
      errors = validator.new(file_path: path).validate
      assert_empty errors, "#{validator} failed: #{errors.map { |error| error.to_h["message"] }.join(", ")}"
    end
  end

  def eliminate_validated_file(file_path:, &block)
    File.delete(file_path) if File.exist?(file_path)
    yield
    validate_talk_file(file_path)
  ensure
    File.delete(file_path) if File.exist?(file_path)
  end
end
