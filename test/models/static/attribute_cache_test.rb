require "test_helper"

class Yerba::Record::AttributeCacheTest < ActiveSupport::TestCase
  include StaticSpeakersSandbox

  setup do
    @tmp_file = Tempfile.new(["videos", ".yml"])
    @tmp_file.write(videos_yaml(50))
    @tmp_file.flush
    @document = Yerba::Record::Document.new(@tmp_file.path)
    @records = (0...50).map { |index| Static::Talk.new(document: @document, index: index) }
  end

  teardown do
    @tmp_file.close
    @tmp_file.unlink
  end

  test "reading fields does not call into Yerba per record or per field" do
    calls = count_yerba_calls do
      3.times do
        @records.each do |record|
          [record.id, record.title, record.video_provider, record.date, record["video_id"], record.to_h, record.speakers.names]
        end
      end
    end

    assert_operator calls, :<=, 5, "Expected reading 50 records to materialize the document once, got #{calls} calls into Yerba"
  end

  test "the number of calls into Yerba does not grow with the number of records" do
    small_file = Tempfile.new(["videos", ".yml"])
    small_file.write(videos_yaml(5))
    small_file.flush
    small_document = Yerba::Record::Document.new(small_file.path)
    small_records = (0...5).map { |index| Static::Talk.new(document: small_document, index: index) }

    small_calls = count_yerba_calls { small_records.each { |record| [record.title, record.speakers.names] } }
    large_calls = count_yerba_calls { @records.each { |record| [record.title, record.speakers.names] } }

    assert_equal small_calls, large_calls
  ensure
    small_file&.close
    small_file&.unlink
  end

  test "writing a field is visible on the next read" do
    record = @records.first
    assert_equal "Talk 1", record.title

    record.title = "Renamed"

    assert_equal "Renamed", record.title
    assert_equal "Renamed", record.to_h["title"]
  end

  test "a write does not leak into other records of the same document" do
    first, second = @records.first(2)
    second.title

    first.title = "Renamed"

    assert_equal "Talk 2", second.title
    assert_equal "Renamed", Static::Talk.new(document: @document, index: 0).title
  end

  test "appending a reference is visible on the next read" do
    record = @records.first
    assert_equal ["Speaker 1"], record.speakers.names

    record.speakers << "Speaker 99"

    assert_equal ["Speaker 1", "Speaker 99"], record.speakers.names
    assert_equal ["Speaker 1", "Speaker 99"], record["speakers"]
  end

  test "deleting a reference is visible on the next read" do
    record = @records.first

    record.speakers.delete("Speaker 1")

    assert_empty record.speakers.names
    assert_empty record["speakers"]
  end

  test "saving re-reads values from the document" do
    record = @records.first
    record.title = "Saved Title"
    record.save!

    reloaded = Static::Talk.new(document: Yerba::Record::Document.new(@tmp_file.path), index: 0)

    assert_equal "Saved Title", record.title
    assert_equal "Saved Title", reloaded.title
  end

  private

  def videos_yaml(count)
    entries = (1..count).map do |index|
      <<~YAML
        - id: "talk-#{index}"
          title: "Talk #{index}"
          video_provider: "youtube"
          video_id: "video-#{index}"
          date: "2025-01-01"
          speakers:
            - "Speaker #{index}"
      YAML
    end

    "---\n#{entries.join}"
  end

  def count_yerba_calls(&block)
    count = 0

    trace = TracePoint.new(:call, :c_call) do |point|
      owner = point.defined_class
      owner = owner.attached_object if owner.respond_to?(:singleton_class?) && owner.singleton_class?
      name = owner.is_a?(Module) ? owner.name.to_s : ""

      count += 1 if name.start_with?("Yerba::") && !name.start_with?("Yerba::Record")
    end

    trace.enable(&block)

    count
  end
end
