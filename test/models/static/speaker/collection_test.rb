require "test_helper"

class Static::Speaker::CollectionTest < ActiveSupport::TestCase
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
    speakers = Static::Speaker.in_file(@tmp_file.path)
    assert_equal 1, speakers.count

    sleep 0.1

    File.write(@tmp_file.path, File.read(@tmp_file.path))
    speakers.add(name: "Aaron Patterson")

    assert_raises(Yerba::StaleFileError) do
      speakers.save!
    end
  end

  test "saves successfully when file has not been modified" do
    speakers = Static::Speaker.in_file(@tmp_file.path)

    assert_nothing_raised do
      speakers.save!
    end
  end

  test "allows consecutive saves on the same instance" do
    speakers = Static::Speaker.in_file(@tmp_file.path)

    speakers.save!
    speakers.save!

    assert_equal 1, speakers.count
  end

  test "resets cached indexes after save" do
    speakers = Static::Speaker.in_file(@tmp_file.path)

    assert_equal 1, speakers.count
    assert_equal({"matz" => 0}, speakers.index_on(:slug).positions)

    speakers.add(name: "Aaron Patterson", github: "tenderlove", slug: "aaron-patterson")
    speakers.save!

    assert_equal 2, speakers.count
    assert_includes speakers.index_on(:slug).positions, "aaron-patterson"
  end

  test "remove_orphaned_speakers! destroys the speakers nothing references" do
    File.write(@tmp_file.path, <<~YAML)
      ---
      - name: "Orphan One XYZZY"
        github: ""
        slug: "orphan-one-xyzzy"

      # Keep this comment
      - name: "Alan Ridlehoover"
        github: ""
        slug: "alan-ridlehoover"

      - name: "Orphan Two XYZZY"
        github: ""
        slug: "orphan-two-xyzzy"
    YAML

    removed = Static::Speaker.in_file(@tmp_file.path).remove_orphaned_speakers!

    assert_equal ["Orphan One XYZZY", "Orphan Two XYZZY"], removed.sort
    assert_equal ["Alan Ridlehoover"], Yerba.parse_file(@tmp_file.path).value_at("[].name")
    assert_includes File.read(@tmp_file.path), "# Keep this comment"
  end

  test "finds a speaker added before saving" do
    speakers = Static::Speaker.in_file(@tmp_file.path)

    assert_nil speakers.find_speaker(name: "Aaron Patterson")

    speakers.add(name: "Aaron Patterson", github: "tenderlove", aliases: [{"name" => "tenderlove", "slug" => "tenderlove"}])

    assert_equal 2, speakers.count
    assert_equal "Aaron Patterson", speakers.find_speaker(name: "Aaron Patterson")["name"]
    assert_equal "Aaron Patterson", speakers.find_speaker(name: "tenderlove")["name"]
    assert_equal "Aaron Patterson", speakers.find_speaker(github: "tenderlove")["name"]
  end

  test "near_duplicate_names clusters near-identical names" do
    file = speakers_with(<<~YAML)
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
    file = speakers_with(<<~YAML)
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
    file = speakers_with(<<~YAML)
      ---
      - name: "Aaron Patterson"
      - name: "Yukihiro Matsumoto"
      - name: "Sam Saffron"
    YAML

    assert_empty file.near_duplicate_names
    assert_empty file.near_duplicate_names(threshold: 0.99)
  end

  test "add raises InvalidSpeakerError when the name is blank" do
    speakers = Static::Speaker.in_file(@tmp_file.path)

    [nil, "", "   "].each do |blank_name|
      error = assert_raises(Static::Speaker::InvalidSpeakerError) do
        speakers.add(name: blank_name)
      end

      assert_equal "Speaker name cannot be blank", error.message
    end

    assert_equal 1, speakers.count
  end

  test "add raises DuplicateSpeakerError when the name already exists" do
    speakers = Static::Speaker.in_file(@tmp_file.path)

    error = assert_raises(Static::Speaker::DuplicateSpeakerError) do
      speakers.add(name: "Matz")
    end

    assert_equal "Speaker 'Matz' already exists", error.message
    assert_equal 1, speakers.count
  end

  test "add strips whitespace" do
    speakers = Static::Speaker.in_file(@tmp_file.path)

    entry = speakers.add(name: "  Aaron Patterson  ", github: "  tenderlove  ")

    assert_equal "Aaron Patterson", entry[:name]
    assert_equal "tenderlove", entry[:github]
    assert_equal "aaron-patterson", entry[:slug]
  end

  test "upsert adds a new speaker with a generated slug" do
    speakers = Static::Speaker.in_file(@tmp_file.path)

    entry = speakers.upsert(name: "Jane Doe")

    assert_instance_of Static::Speaker, entry
    assert_equal({"name" => "Jane Doe", "github" => "", "slug" => "jane-doe"}, entry.to_h)
    assert_equal 2, speakers.count
  end

  test "upsert updates attributes of an existing speaker found by name" do
    speakers = Static::Speaker.in_file(@tmp_file.path)

    entry = speakers.upsert(name: "Matz", github: "", twitter: " yukihiro_matz ")

    assert_equal "matz", entry["github"]
    assert_equal "yukihiro_matz", entry["twitter"]
  end

  test "upsert finds an existing speaker by github handle and keeps their name" do
    file = speakers_with(<<~YAML)
      ---
      - name: Yukihiro Matsumoto
        github: matz
        slug: yukihiro-matsumoto
    YAML

    entry = file.upsert(name: "Matz", github: "matz", website: "https://matz.rubyist.net")

    assert_equal "Yukihiro Matsumoto", entry["name"]
    assert_equal "https://matz.rubyist.net", entry["website"]
    assert_equal 1, file.count
  end

  test "upsert matches an alias without renaming the canonical speaker" do
    file = speakers_with(<<~YAML)
      ---
      - name: Jane Doe
        slug: jane-doe
        aliases:
          - name: JD
            slug: jane-doe
    YAML

    entry = file.upsert(name: "JD", github: "janedoe")

    assert_equal "Jane Doe", entry["name"]
    assert_equal "janedoe", entry["github"]
    assert_equal 1, file.count
  end

  test "add raises DuplicateSpeakerError when the github handle already exists" do
    speakers = Static::Speaker.in_file(@tmp_file.path)

    error = assert_raises(Static::Speaker::DuplicateSpeakerError) do
      speakers.add(name: "Yukihiro Matsumoto", github: "matz")
    end

    assert_equal "A speaker with GitHub handle 'matz' already exists", error.message
    assert_equal 1, speakers.count
  end

  test "upsert does not overwrite attributes with whitespace-only values" do
    speakers = Static::Speaker.in_file(@tmp_file.path)

    entry = speakers.upsert(name: "Matz", github: "   ", twitter: "   ")

    assert_equal "matz", entry["github"]
    assert_nil entry["twitter"]
  end

  test "upsert raises InvalidSpeakerError when the name is blank" do
    speakers = Static::Speaker.in_file(@tmp_file.path)

    assert_raises(Static::Speaker::InvalidSpeakerError) do
      speakers.upsert(name: "")
    end

    assert_equal 1, speakers.count
  end

  private

  def speakers_with(yaml)
    tmp = Tempfile.new(["speakers", ".yml"])
    tmp.write(yaml)
    tmp.flush
    @extra_tmp_files << tmp
    Static::Speaker.in_file(tmp.path)
  end
end
