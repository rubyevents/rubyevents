require "test_helper"

class SpeakerUpdateToolTest < ActiveSupport::TestCase
  setup do
    @tmp_file = Tempfile.new(["speakers", ".yml"])
    @tmp_file.write(<<~YAML)
      ---
      - name: "Matz"
        github: "matz"
        twitter: "yukihiro_matz"
        slug: "matz"
        mastodon: ""
        website: ""
      - name: "Aaron Patterson"
        github: "tenderlove"
        twitter: "tendloving"
        mastodon: "https://mastodon.social/@tenderlove"
        slug: "aaron-patterson"
        website: ""
      - name: "DHH"
        github: "dhh"
        twitter: ""
        linkedin: "dhh"
        slug: "dhh"
        website: ""
    YAML
    @tmp_file.flush
    @tool = SpeakerUpdateTool.new(speakers_file_path: @tmp_file.path)
  end

  teardown do
    @tmp_file.close
    @tmp_file.unlink
  end

  test "updates a single field" do
    result = @tool.execute(name: "Matz", twitter: "maboroshi_matz")

    assert result[:success]
    assert_equal "Matz", result[:speaker]
    assert_equal({twitter: "maboroshi_matz"}, result[:updated_fields])

    speaker = Static::SpeakersFile.new(@tmp_file.path).find_by(name: "Matz")
    assert_equal "maboroshi_matz", speaker["twitter"]
    assert_equal "matz", speaker["github"]
  end

  test "updates multiple fields" do
    result = @tool.execute(name: "DHH", twitter: "dhh", website: "https://dhh.dk")

    assert result[:success]

    speaker = Static::SpeakersFile.new(@tmp_file.path).find_by(name: "DHH")
    assert_equal "dhh", speaker["twitter"]
    assert_equal "https://dhh.dk", speaker["website"]
  end

  test "returns error for unknown speaker" do
    result = @tool.execute(name: "Nobody", twitter: "nobody")

    assert_equal "Speaker 'Nobody' not found in speakers.yml", result[:error]
  end

  test "returns error when no updatable fields provided" do
    result = @tool.execute(name: "Matz")

    assert_match(/No fields to update/, result[:error])
  end

  test "rejects URL in handle field" do
    result = @tool.execute(name: "Matz", github: "https://github.com/matz")

    assert_match(/should be a username, not a URL/, result[:error])

    speaker = Static::SpeakersFile.new(@tmp_file.path).find_by(name: "Matz")
    assert_equal "matz", speaker["github"]
  end

  test "creates alias when slug changes" do
    result = @tool.execute(name: "Aaron Patterson", slug: "tenderlove")

    assert result[:success]
    assert_equal "Aaron Patterson (aaron-patterson)", result[:alias_created]

    speaker = Static::SpeakersFile.new(@tmp_file.path).find_by(name: "Aaron Patterson")
    assert_equal "tenderlove", speaker["slug"]
    assert_equal 1, speaker["aliases"].size
    assert_equal "aaron-patterson", speaker["aliases"].first["slug"]
  end

  test "does not create alias when slug is unchanged" do
    result = @tool.execute(name: "Matz", slug: "matz")

    assert result[:success]
    assert_nil result[:alias_created]

    speaker = Static::SpeakersFile.new(@tmp_file.path).find_by(name: "Matz")
    assert_nil speaker["aliases"]
  end

  test "allows mastodon URL" do
    @tool.execute(name: "Matz", mastodon: "https://ruby.social/@matz")

    speaker = Static::SpeakersFile.new(@tmp_file.path).find_by(name: "Matz")
    assert_equal "https://ruby.social/@matz", speaker["mastodon"]
  end

  test "allows website URL" do
    @tool.execute(name: "DHH", website: "https://dhh.dk")

    speaker = Static::SpeakersFile.new(@tmp_file.path).find_by(name: "DHH")
    assert_equal "https://dhh.dk", speaker["website"]
  end
end
