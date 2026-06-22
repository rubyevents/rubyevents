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
  end

  teardown do
    @tmp_file.close
    @tmp_file.unlink
  end

  test "raises StaleFileError when file was modified externally" do
    speakers_file = Static::SpeakersFile.new(@tmp_file.path)

    sleep 0.1

    File.write(@tmp_file.path, File.read(@tmp_file.path))

    assert_raises(Yerba::StaleFileError) do
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
end
