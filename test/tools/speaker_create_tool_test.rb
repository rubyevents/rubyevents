require "test_helper"

class SpeakerCreateToolTest < ActiveSupport::TestCase
  setup do
    @tmp_file = Tempfile.new(["speakers", ".yml"])
    @tmp_file.write(<<~YAML)
      ---
      - name: "Matz"
        github: "matz"
        twitter: "yukihiro_matz"
        slug: "matz"
      - name: "Aaron Patterson"
        github: "tenderlove"
        slug: "aaron-patterson"
    YAML
    @tmp_file.flush
    @tool = SpeakerCreateTool.new(speakers_file_path: @tmp_file.path)
  end

  teardown do
    @tmp_file.close
    @tmp_file.unlink
  end

  test "creates a new speaker with name and github" do
    result = @tool.execute(name: "Sandi Metz", github: "sandimetz")

    assert result[:success]

    speaker = Static::SpeakersFile.new(@tmp_file.path).find_by(name: "Sandi Metz")
    assert_not_nil speaker
    assert_equal "sandimetz", speaker["github"]
    assert_equal "sandi-metz", speaker["slug"]
  end

  test "creates a speaker with custom slug" do
    @tool.execute(name: "Sandi Metz", github: "sandimetz", slug: "sandi")

    speaker = Static::SpeakersFile.new(@tmp_file.path).find_by(name: "Sandi Metz")
    assert_equal "sandi", speaker["slug"]
  end

  test "creates a speaker with optional social fields" do
    @tool.execute(name: "Sandi Metz", github: "sandimetz", twitter: "sandimetz", website: "https://sandimetz.com")

    speaker = Static::SpeakersFile.new(@tmp_file.path).find_by(name: "Sandi Metz")
    assert_equal "sandimetz", speaker["twitter"]
    assert_equal "https://sandimetz.com", speaker["website"]
  end

  test "auto-generates slug from name" do
    @tool.execute(name: "Jean-Michel Boudreaux")

    speaker = Static::SpeakersFile.new(@tmp_file.path).find_by(name: "Jean-Michel Boudreaux")
    assert_equal "jean-michel-boudreaux", speaker["slug"]
  end

  test "returns error if speaker already exists" do
    result = @tool.execute(name: "Matz", github: "matz")

    assert_equal "Speaker 'Matz' already exists in speakers.yml", result[:error]
    assert_equal 2, Static::SpeakersFile.new(@tmp_file.path).count
  end

  test "returns error if slug already taken" do
    result = @tool.execute(name: "New Person", slug: "matz")

    assert_equal "A speaker with slug 'matz' already exists in speakers.yml", result[:error]
    assert_equal 2, Static::SpeakersFile.new(@tmp_file.path).count
  end

  test "rejects URL in github field" do
    result = @tool.execute(name: "New Person", github: "https://github.com/newperson")

    assert_match(/should be a username, not a URL/, result[:error])
    assert_equal 2, Static::SpeakersFile.new(@tmp_file.path).count
  end

  test "rejects URL in handle field" do
    result = @tool.execute(name: "New Person", twitter: "https://twitter.com/newperson")

    assert_match(/should be a username, not a URL/, result[:error])
    assert_equal 2, Static::SpeakersFile.new(@tmp_file.path).count
  end

  test "returns error when no name or github provided" do
    result = @tool.execute

    assert_equal "Provide at least a name or a github handle", result[:error]
    assert_equal 2, Static::SpeakersFile.new(@tmp_file.path).count
  end
end
