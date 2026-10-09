require "test_helper"

class SpeakerAddAliasToolTest < ActiveSupport::TestCase
  setup do
    @tmp_file = Tempfile.new(["speakers", ".yml"])
    @tmp_file.write(<<~YAML)
      ---
      - name: "Matz"
        github: "matz"
        twitter: "yukihiro_matz"
        slug: "matz"
        aliases:
          - name: "Yukihiro Matsumoto"
            slug: "yukihiro-matsumoto"
      - name: "Aaron Patterson"
        github: "tenderlove"
        slug: "aaron-patterson"
        aliases:
          - name: "tenderlove"
            slug: "tenderlove"
      - name: "DHH"
        github: "dhh"
        slug: "dhh"
        aliases:
          - name: "David Heinemeier Hansson"
            slug: "david-heinemeier-hansson"
    YAML
    @tmp_file.flush
    @tool = SpeakerAddAliasTool.new(speakers_file_path: @tmp_file.path)
  end

  teardown do
    @tmp_file.close
    @tmp_file.unlink
  end

  test "adds alias to speaker" do
    result = @tool.execute(name: "Aaron Patterson", alias_name: "Aaron P")

    assert result[:success]
    assert_equal 2, result[:total_aliases]

    speaker = Static::SpeakersFile.new(@tmp_file.path).find_by(name: "Aaron Patterson")
    alias_slugs = speaker["aliases"].map { |a| a["slug"] }
    assert_includes alias_slugs, "tenderlove"
    assert_includes alias_slugs, "aaron-p"
  end

  test "adds alias to speaker with existing aliases" do
    @tool.execute(name: "Matz", alias_name: "Matz-san")

    speaker = Static::SpeakersFile.new(@tmp_file.path).find_by(name: "Matz")
    alias_names = speaker["aliases"].map { |a| a["name"] }
    assert_includes alias_names, "Yukihiro Matsumoto"
    assert_includes alias_names, "Matz-san"
  end

  test "uses custom slug when provided" do
    @tool.execute(name: "DHH", alias_name: "David", alias_slug: "david-h")

    speaker = Static::SpeakersFile.new(@tmp_file.path).find_by(name: "DHH")
    alias_entry = speaker["aliases"].find { |a| a["name"] == "David" }
    assert_equal "david-h", alias_entry["slug"]
  end

  test "auto-generates slug from alias name" do
    @tool.execute(name: "DHH", alias_name: "David H. Hansson")

    speaker = Static::SpeakersFile.new(@tmp_file.path).find_by(name: "DHH")
    alias_entry = speaker["aliases"].find { |a| a["name"] == "David H. Hansson" }
    assert_equal "david-h-hansson", alias_entry["slug"]
  end

  test "returns error for unknown speaker" do
    result = @tool.execute(name: "Nobody", alias_name: "Ghost")

    assert_equal "Speaker 'Nobody' not found in speakers.yml", result[:error]
  end

  test "rejects duplicate alias by slug" do
    result = @tool.execute(name: "Matz", alias_name: "Another Matz", alias_slug: "yukihiro-matsumoto")

    assert_match(/already exists/, result[:error])

    speaker = Static::SpeakersFile.new(@tmp_file.path).find_by(name: "Matz")
    assert_equal 1, speaker["aliases"].size
  end

  test "rejects duplicate alias by name" do
    result = @tool.execute(name: "Matz", alias_name: "Yukihiro Matsumoto")

    assert_match(/already exists/, result[:error])

    speaker = Static::SpeakersFile.new(@tmp_file.path).find_by(name: "Matz")
    assert_equal 1, speaker["aliases"].size
  end
end
