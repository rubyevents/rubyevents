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
          - "Yukihiro Matsumoto"
      - name: "Aaron Patterson"
        github: "tenderlove"
        slug: "aaron-patterson"
        aliases:
          - "Aaron Lee Patterson"
      - name: "DHH"
        github: "dhh"
        slug: "dhh"
    YAML
    @tmp_file.flush
    @tool = SpeakerAddAliasTool.new(speakers_file_path: @tmp_file.path)
  end

  teardown do
    @tmp_file.close
    @tmp_file.unlink
  end

  test "adds alias to speaker" do
    result = @tool.execute(name: "DHH", alias_name: "David Heinemeier Hansson")

    assert result[:success]
    assert_equal "David Heinemeier Hansson", result[:alias_added]
    assert_equal 1, result[:total_aliases]

    speaker = Static::Speaker.in_file(@tmp_file.path).find_by(name: "DHH")
    assert_equal ["David Heinemeier Hansson"], speaker.alias_names
  end

  test "adds alias to speaker with existing aliases" do
    result = @tool.execute(name: "Aaron Patterson", alias_name: "Aaron P")

    assert_equal 2, result[:total_aliases]

    speaker = Static::Speaker.in_file(@tmp_file.path).find_by(name: "Aaron Patterson")
    assert_equal ["Aaron Lee Patterson", "Aaron P"], speaker.alias_names
  end

  test "returns error for unknown speaker" do
    result = @tool.execute(name: "Nobody", alias_name: "Ghost")

    assert_equal "Speaker 'Nobody' not found in speakers.yml", result[:error]
  end

  test "rejects duplicate alias by name, ignoring case" do
    result = @tool.execute(name: "Matz", alias_name: "yukihiro matsumoto")

    assert_match(/already exists/, result[:error])

    speaker = Static::Speaker.in_file(@tmp_file.path).find_by(name: "Matz")
    assert_equal ["Yukihiro Matsumoto"], speaker.alias_names
  end

  test "rejects the speaker's own name as alias" do
    result = @tool.execute(name: "Matz", alias_name: "Matz")

    assert_match(/already exists/, result[:error])
  end
end
