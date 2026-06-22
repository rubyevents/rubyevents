require "test_helper"

class Static::ReferencesProxyTest < ActiveSupport::TestCase
  setup do
    @tmp_file = Tempfile.new(["videos", ".yml"])
    @tmp_file.write(<<~YAML)
      ---
      - id: "talk-1"
        title: "Ruby 4.0"
        speakers:
          - Matz
          - Aaron Patterson
    YAML
    @tmp_file.flush
    @document = Yerba::Record::Document.new(@tmp_file.path)
  end

  teardown do
    @tmp_file.close
    @tmp_file.unlink
  end

  test "resolves speakers to Static::Speaker" do
    video = Static::Video.new(document: @document, index: 0)

    resolved = video.speakers.first
    assert_instance_of Static::Speaker, resolved
    assert_equal "matz", resolved.github
  end

  test "falls back to raw string when speaker not found" do
    @document.root[0]["speakers"] << "Nonexistent Person 12345"

    video = Static::Video.new(document: @document, index: 0)
    last = video.speakers.to_a.last

    assert_equal "Nonexistent Person 12345", last
  end

  test "names returns raw string array" do
    video = Static::Video.new(document: @document, index: 0)

    assert_equal ["Matz", "Aaron Patterson"], video.speakers.names
  end

  test "count returns number of speakers" do
    video = Static::Video.new(document: @document, index: 0)

    assert_equal 2, video.speakers.count
  end

  test "empty? returns false for non-empty speakers" do
    video = Static::Video.new(document: @document, index: 0)

    assert_not video.speakers.empty?
  end

  test "empty? returns true for missing speakers" do
    @tmp_file.rewind
    @tmp_file.truncate(0)
    @tmp_file.write(<<~YAML)
      ---
      - id: "talk-1"
        title: "Ruby 4.0"
    YAML
    @tmp_file.flush

    document = Yerba::Record::Document.new(@tmp_file.path)
    video = Static::Video.new(document: document, index: 0)

    assert video.speakers.empty?
  end

  test "include? checks by name" do
    video = Static::Video.new(document: @document, index: 0)

    assert video.speakers.include?("Matz")
    assert_not video.speakers.include?("DHH")
  end

  test "<< appends speaker name to the YAML" do
    video = Static::Video.new(document: @document, index: 0)

    video.speakers << "DHH"

    assert_includes video.speakers.names, "DHH"
    assert_equal 3, video.speakers.count
  end

  test "<< auto-creates speaker in speakers.yml if not found" do
    video = Static::Video.new(document: @document, index: 0)
    unique_name = "Test Speaker #{SecureRandom.hex(4)}"

    video.speakers << unique_name

    speaker = Static::Speakers.find_by(name: unique_name)
    assert_not_nil speaker, "Expected speaker to be auto-created in speakers.yml"
    assert_equal unique_name.parameterize, speaker.slug
  ensure
    Static::Speakers.reset!
  end

  test "<< does not duplicate existing speaker in speakers.yml" do
    video = Static::Video.new(document: @document, index: 0)

    speaker_before = Static::Speakers.find_by(name: "Matz")
    assert_not_nil speaker_before

    video.speakers << "Matz"

    assert_includes video.speakers.names, "Matz"
    assert_equal video.speakers.names.count("Matz"), 2
  end

  test "each yields resolved entries" do
    video = Static::Video.new(document: @document, index: 0)

    all_resolved = video.speakers.all? { |speaker| speaker.is_a?(Static::Speaker) }
    assert all_resolved

    github_handles = video.speakers.map { |speaker| speaker.github.to_s }
    assert_includes github_handles, "matz"
    assert_includes github_handles, "tenderlove"
  end

  test "enumerable methods work" do
    video = Static::Video.new(document: @document, index: 0)

    found = video.speakers.any? { |speaker| speaker.respond_to?(:github) && speaker.github == "matz" }
    assert found
  end

  test "delete removes speaker from the YAML" do
    video = Static::Video.new(document: @document, index: 0)

    video.speakers.delete("Aaron Patterson")

    assert_equal ["Matz"], video.speakers.names
  end

  test "save! on parent entry persists speaker changes" do
    video = Static::Video.new(document: @document, index: 0)

    video.speakers << "DHH"
    video.save!

    reloaded = Yerba::Record::Document.new(@tmp_file.path)
    reloaded_video = Static::Video.new(document: reloaded, index: 0)

    assert_includes reloaded_video.speakers.names, "DHH"
  end

  test "inspect shows names" do
    video = Static::Video.new(document: @document, index: 0)

    assert_match(/Matz/, video.speakers.inspect)
    assert_match(/Aaron Patterson/, video.speakers.inspect)
  end
end
