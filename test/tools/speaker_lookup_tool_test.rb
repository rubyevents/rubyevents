require "test_helper"

class SpeakerLookupToolTest < ActiveSupport::TestCase
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
        twitter: "tendloving"
        mastodon: "https://mastodon.social/@tenderlove"
        slug: "aaron-patterson"
      - name: "DHH"
        github: "dhh"
        linkedin: "dhh"
        slug: "dhh"
    YAML
    @tmp_file.flush
  end

  teardown do
    @tmp_file.close
    @tmp_file.unlink
  end

  test "finds speaker by name" do
    result = build_tool.execute(query: "Matz")

    assert_equal 1, result.size
    assert_equal "Matz", result.first[:name]
  end

  test "finds speaker by github handle" do
    result = build_tool.execute(query: "tenderlove")

    assert_equal 1, result.size
    assert_equal "Aaron Patterson", result.first[:name]
  end

  test "finds speaker by alias name" do
    result = build_tool.execute(query: "Yukihiro Matsumoto")

    assert_equal 1, result.size
    assert_equal "Matz", result.first[:name]
    assert_includes result.first[:aliases], "Yukihiro Matsumoto"
  end

  test "finds speaker by slug" do
    result = build_tool.execute(query: "aaron-patterson")

    assert_equal 1, result.size
    assert_equal "Aaron Patterson", result.first[:name]
  end

  test "case insensitive search" do
    result = build_tool.execute(query: "matz")

    assert_equal 1, result.size
    assert_equal "Matz", result.first[:name]
  end

  test "returns empty array when no matches" do
    result = build_tool.execute(query: "nonexistent")

    assert_equal [], result
  end

  test "returns multiple matches for partial query" do
    result = build_tool.execute(query: "a")

    assert result.size > 1
  end

  private

  def build_tool
    SpeakerLookupTool.new(speakers_file_path: @tmp_file.path)
  end
end
