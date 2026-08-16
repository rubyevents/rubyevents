require "test_helper"

class Static::SpeakersFileTest < ActiveSupport::TestCase
  setup do
    @tmp_file = Tempfile.new(["speakers", ".yml"])
    @tmp_file.write(<<~YAML)
      ---
      - name: "Matz"
        github: "matz"
        slug: "matz"
    YAML
    @tmp_file.flush
    @extra_tmp_files = []
  end

  teardown do
    @tmp_file.close
    @tmp_file.unlink

    @extra_tmp_files.each do |file|
      file.close
      file.unlink
    end
  end

  test "raises StaleFileError when file was modified externally" do
    speakers_file = Static::SpeakersFile.new(@tmp_file.path)

    sleep 0.1

    File.write(@tmp_file.path, File.read(@tmp_file.path))

    assert_raises(Static::SpeakersFile::StaleFileError) do
      speakers_file.save!
    end
  end

  test "saves successfully when file has not been modified" do
    speakers_file = Static::SpeakersFile.new(@tmp_file.path)

    assert_nothing_raised do
      speakers_file.save!
    end
  end

  test "allows consecutive saves on the same instance" do
    speakers_file = Static::SpeakersFile.new(@tmp_file.path)

    speakers_file.save!
    speakers_file.save!

    assert_equal 1, speakers_file.count
  end

  test "resets cached indexes after save" do
    speakers_file = Static::SpeakersFile.new(@tmp_file.path)

    assert_equal 1, speakers_file.count
    assert_equal({"matz" => 0}, speakers_file.index_by(:slug))

    speakers_file.add(name: "Aaron Patterson", github: "tenderlove", slug: "aaron-patterson")
    speakers_file.save!

    assert_equal 2, speakers_file.count
    assert_includes speakers_file.index_by(:slug), "aaron-patterson"
  end

  test "near_duplicate_names clusters near-identical names" do
    file = speakers_file_with(<<~YAML)
      ---
      - name: "Pat Shaughnessy"
        github: "pat"
        slug: "pat-shaughnessy"
      - name: "Pat Saughnessy"
        github: ""
        slug: "pat-saughnessy"
      - name: "Yukihiro Matsumoto"
        github: "matz"
        slug: "yukihiro-matsumoto"
    YAML

    clusters = file.near_duplicate_names

    assert_equal 1, clusters.size
    assert_equal ["Pat Saughnessy", "Pat Shaughnessy"], clusters.first.names
    assert_in_delta 0.93, clusters.first.score, 0.02
  end

  test "near_duplicate_names groups 3+ variants into one cluster" do
    file = speakers_file_with(<<~YAML)
      ---
      - name: "Masayoshi Takahashi"
      - name: "Masayoshi Takahasi"
      - name: "Maysayoshi Takahashi"
    YAML

    clusters = file.near_duplicate_names

    assert_equal 1, clusters.size
    assert_equal 3, clusters.first.names.size
  end

  test "near_duplicate_names ignores distinct names and respects the threshold" do
    file = speakers_file_with(<<~YAML)
      ---
      - name: "Aaron Patterson"
      - name: "Yukihiro Matsumoto"
      - name: "Sam Saffron"
    YAML

    assert_empty file.near_duplicate_names
    assert_empty file.near_duplicate_names(threshold: 0.99)
  end

  private

  def speakers_file_with(yaml)
    tmp = Tempfile.new(["speakers", ".yml"])
    tmp.write(yaml)
    tmp.flush
    @extra_tmp_files << tmp
    Static::SpeakersFile.new(tmp.path)
  end
end
