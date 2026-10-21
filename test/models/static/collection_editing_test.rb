require "test_helper"

class Yerba::Record::CollectionEditingTest < ActiveSupport::TestCase
  include StaticSpeakersSandbox

  VIDEOS = <<~YAML
    ---
    - id: "opening" # keep this comment
      title: "Opening"
      date: "2025-01-01"
      video_provider: "youtube"
      video_id: "opening"
      speakers:
        - "Alice"

    - id: "lightning-talks"
      title: "Lightning Talks"
      date: "2025-01-01"
      video_provider: "children"
      video_id: "lightning-talks"
      talks:
        - id: "lightning-one"
          title: "Lightning One"
          date: "2025-01-01"
          video_provider: "parent"
          video_id: "lightning-one"
          speakers:
            - "Bob"

        - id: "lightning-two" # second child
          title: "Lightning Two"
          date: "2025-01-01"
          video_provider: "parent"
          video_id: "lightning-two"
          speakers:
            - "Carol"

    - id: "closing"
      title: "Closing"
      date: "2025-01-01"
      video_provider: "youtube"
      video_id: "closing"
      speakers:
        - "Dave"
  YAML

  setup do
    @dir = Dir.mktmpdir
    @path = File.join(@dir, "videos.yml")
    File.write(@path, VIDEOS)
  end

  teardown do
    FileUtils.rm_rf(@dir)
  end

  def talks
    Static::Talk.in_file(@path)
  end

  def ids_on_disk(selector = "[].id")
    Yerba.parse_file(@path).value_at(selector)
  end

  test "in_file returns a collection of the model with one file" do
    collection = talks

    assert_kind_of Yerba::Record::Collection, collection
    assert collection.single_file?
    assert_equal %w[opening lightning-talks lightning-one lightning-two closing], collection.map(&:id)
    assert_equal %w[opening lightning-talks closing], collection.top_level.map(&:id)
  end

  test "count takes a block like Enumerable#count" do
    assert_equal 5, talks.count
    assert_equal 2, talks.count(&:parent)
  end

  test "nested children are writable records sharing the document" do
    lightning_talks = talks.find_by(id: "lightning-talks")
    child = lightning_talks.talks.find_by(id: "lightning-two")

    assert_equal lightning_talks, child.parent
    assert_equal "[1].talks[1]", child.selector
    assert_equal @path, child.file_path

    child["title"] = "Renamed Lightning"
    child.save!

    assert_equal "Renamed Lightning", Yerba.parse_file(@path).value_at("[1].talks[1].title")
  end

  test "a child write is visible on the parent" do
    lightning_talks = talks.find_by(id: "lightning-talks")
    assert_equal "Lightning One", lightning_talks["talks"].first["title"]

    lightning_talks.talks.first["title"] = "Changed"

    assert_equal "Changed", lightning_talks["talks"].first["title"]
  end

  test "children can append and delete speakers" do
    child = talks.find_by(id: "lightning-talks").talks.first

    child.speakers << "Erin"
    child.save!

    assert_equal %w[Bob Erin], Yerba.parse_file(@path).value_at("[1].talks[0].speakers")
  end

  test "insert adds a key at a position and delete removes it" do
    talk = talks.first

    talk.insert("published_at", "2025-01-02", after: "date")
    talk.delete("video_id")
    talk.save!

    entry = Yerba.parse_file(@path).value_at("[0]")
    assert_equal %w[id title date published_at video_provider speakers], entry.keys
  end

  test "source_line reports where a record and its values are" do
    child = talks.find_by(id: "lightning-talks").talks.last

    assert_equal 24, child.source_line
    assert_equal 25, child.source_line("title")
  end

  test "source_line takes a selector relative to the record" do
    opening = talks.find_by(id: "opening")
    lightning_talks = talks.find_by(id: "lightning-talks")

    assert_equal 8, opening.source_line("speakers[0]")
    assert_equal 25, lightning_talks.source_line("talks[1].title")
    assert_equal 30, lightning_talks.talks.last.source_line("speakers[0]")
    assert_nil opening.source_line("speakers[5]")
  end

  test "source_location of a record in an empty document is nil" do
    event = Static::Event.parse("# TODO: add the event\n", path: File.join(@dir, "event.yml")).first

    assert_nil event["id"]
    assert_nil event.source_location("id")
  end

  test "set replaces a value or inserts it at a position, with a quote style" do
    opening = talks.find_by(id: "opening")

    opening.set("title", "Welcome", quote_style: :single)
    opening.set("published_at", "2025-01-02", after: "date", quote_style: :double)
    opening.save!

    assert_includes File.read(@path), "  title: 'Welcome'\n  date: \"2025-01-01\"\n  published_at: \"2025-01-02\"\n"
  end

  test "create inserts at a position and returns the new record" do
    record = talks.create({id: "keynote", title: "Keynote", date: "2025-01-01", video_provider: "youtube", video_id: "keynote", speakers: ["Eve"]}, after: "opening")

    assert_equal "keynote", record.id
    assert_equal %w[opening keynote lightning-talks closing], ids_on_disk
  end

  test "create on nested children inserts into the parent's talks" do
    lightning_talks = talks.find_by(id: "lightning-talks")

    lightning_talks.talks.create({id: "lightning-zero", title: "Lightning Zero", date: "2025-01-01", video_provider: "parent", video_id: "lightning-zero", speakers: ["Zed"]}, at: 0)

    assert_equal %w[lightning-zero lightning-one lightning-two], ids_on_disk("[1].talks[].id")
  end

  test "reorder sets the running order and keeps comments" do
    talks.reorder(%w[closing opening lightning-talks])

    assert_equal %w[closing opening lightning-talks], ids_on_disk
    assert_includes File.read(@path), %(- id: "opening" # keep this comment)
  end

  test "move reorders nested children" do
    lightning_talks = talks.find_by(id: "lightning-talks")

    lightning_talks.talks.move("lightning-two", to: 0)

    assert_equal %w[lightning-two lightning-one], ids_on_disk("[1].talks[].id")
    assert_includes File.read(@path), %(- id: "lightning-two" # second child)
  end

  test "reorder requires exactly the current ids" do
    assert_raises(ArgumentError) { talks.reorder(%w[closing opening]) }
  end

  test "a destroyed record keeps its own attributes and can't be changed" do
    opening = talks.find_by(id: "opening")

    opening.destroy

    assert_equal "opening", opening.id
    assert_equal "Opening", opening["title"]
    assert opening.destroyed?
    assert_not opening.persisted?
    assert_raises(FrozenError) { opening["title"] = "Changed" }
    assert_raises(FrozenError) { opening.save! }
    assert_equal %w[lightning-talks closing], ids_on_disk
  end

  test "destroy removes a record by id" do
    talks.destroy("closing")

    assert_equal %w[opening lightning-talks], ids_on_disk
  end

  test "the running order survives the videos.yml Yerbafile rules on save" do
    data_dir = Rails.root.join("data", "yerba-record-test", "yerba-record-test-#{SecureRandom.hex(4)}")
    FileUtils.mkdir_p(data_dir)
    path = data_dir.join("videos.yml").to_s
    entries = %w[opening middle closing].map do |id|
      %(- id: "#{id}"\n  title: "#{id.titleize}"\n  description: ""\n  date: "2025-01-01"\n  video_provider: "not_recorded"\n  video_id: "#{id}"\n)
    end
    File.write(path, "---\n#{entries.join("\n")}")

    Static::Talk.in_file(path).reorder(%w[closing opening middle])

    assert_equal %w[closing opening middle], Yerba.parse_file(path).value_at("[].id")
  ensure
    FileUtils.rm_rf(Rails.root.join("data", "yerba-record-test"))
  end

  test "collections run the model's class methods and scopes over themselves" do
    model = Class.new(Yerba::Record::Base) do
      self.path = "unused.yml"

      scope :closing, -> { where(id: "closing") }

      def self.titles = all.map { |record| record["title"] }
    end

    assert_equal ["Opening", "Lightning Talks", "Closing"], model.in_file(@path).titles
    assert_equal ["Closing"], model.in_file(@path).where(id: "closing").titles
    assert_equal ["Closing"], model.in_file(@path).closing.titles
    assert_equal ["Opening"], model.parse(VIDEOS).where.not(id: %w[lightning-talks closing]).titles
  end

  test "reading nested children materializes the document once" do
    lightning_talks = talks.find_by(id: "lightning-talks")
    calls = count_yerba_calls { 3.times { lightning_talks.talks.each { |child| [child.id, child.title, child.speakers.names, child.to_h] } } }

    assert_operator calls, :<=, 5
  end

  private

  def count_yerba_calls(&block)
    count = 0

    trace = TracePoint.new(:c_call) do |point|
      owner = point.defined_class
      owner = owner.attached_object if owner.respond_to?(:singleton_class?) && owner.singleton_class?
      name = owner.is_a?(Module) ? owner.name.to_s : ""

      next if name == "Yerba::Document" && point.method_id == :values
      next unless name.start_with?("Yerba::") && !name.start_with?("Yerba::Record")

      # attr_readers like `Yerba::Selector#segments` are C methods too, but defined in Ruby source
      next if point.self.method(point.method_id).source_location

      count += 1
    end

    trace.enable(&block)

    count
  end
end
