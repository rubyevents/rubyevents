# frozen_string_literal: true

require "test_helper"

class Static::ValidationsTest < ActiveSupport::TestCase
  class Conference < Yerba::Record::Base
    self.path = "data/:series_id/:id/conference.yml"

    has_file :avatar, "images/:series_id/:id/avatar.webp"

    validates :title, presence: true
    validates :id, matches_path: true
    validate :not_cancelled
    validate(on: :lint) { errors.add(:base, "needs a website") if self["website"].blank? }
    validate { errors.add(:location, "should be set", severity: :warning) if self["location"].blank? }
    validates :avatar, file: {presence: true}, on: :lint

    private

    def not_cancelled
      errors.add(:status, "can't be cancelled") if self["status"] == "cancelled"
    end
  end

  class Item < Yerba::Record::Base
    self.path = "data/:event_id/items.yml"
    self.flatten = true

    validates :title, presence: true
    validates :id, uniqueness: {also: :old_id}
  end

  setup do
    @root = Dir.mktmpdir
    Conference.root = @root
    Item.root = @root
  end

  teardown do
    Conference.unload!
    Item.unload!
    FileUtils.rm_rf(@root)
  end

  test "validates with built-in validators, a validator class, a method and a block" do
    conference = write_conference("id" => "other", "title" => nil, "status" => "cancelled", "location" => nil)

    assert_not conference.valid?
    assert_equal ["title can't be blank", %(id "other" does not match the folder name "conf-2025"), "status can't be cancelled", "location should be set"], conference.errors.full_messages
  end

  test "lint validations only run in the lint context" do
    conference = write_conference

    assert conference.valid?
    assert_not conference.valid?(:lint)
    assert_includes conference.errors.full_messages, "needs a website"
    assert_includes conference.errors.full_messages, "avatar file is missing at images/conf/conf-2025/avatar.webp"
  end

  test "file validation passes when the file exists" do
    conference = write_conference("website" => "https://example.com")
    FileUtils.mkdir_p(File.join(@root, "images/conf/conf-2025"))
    FileUtils.touch(File.join(@root, "images/conf/conf-2025/avatar.webp"))

    assert conference.valid?(:lint)
  end

  test "save! raises and leaves the file untouched when invalid" do
    conference = write_conference
    conference["title"] = ""

    error = assert_raises(Yerba::Record::RecordInvalid) { conference.save! }

    assert_equal "Validation failed: title can't be blank", error.message
    assert_equal conference, error.record
    assert_includes File.read(conference.file_path), "title: Conf 2025"
  end

  test "save returns false when invalid and save!(validate: false) skips validations" do
    conference = write_conference
    conference["title"] = ""

    assert_equal false, conference.save
    assert_nothing_raised { conference.save!(validate: false) }
    assert_includes File.read(conference.file_path), %(title: "")
  end

  test "warnings don't block a save" do
    conference = write_conference("location" => nil)
    conference["title"] = "Renamed"

    assert_nothing_raised { conference.save! }
    assert_includes File.read(conference.file_path), "title: Renamed"
  end

  test "error_location points at the attribute, or at the record when it's missing" do
    conference = write_conference("status" => "cancelled", "location" => nil)
    conference.valid?

    status_error = conference.errors.find { |error| error.attribute == :status }
    location_error = conference.errors.find { |error| error.attribute == :location }

    assert_equal 5, conference.error_location(status_error).start_line
    assert_equal 1, conference.error_location(location_error).start_line
    assert conference.error_warning?(location_error)
    assert_not conference.error_warning?(status_error)
  end

  test "uniqueness checks every record of the model and shares a namespace with also:" do
    write_items("a", [{"id" => "one", "title" => "A"}, {"id" => "two", "old_id" => "legacy", "title" => "B"}])
    write_items("b", [{"id" => "legacy", "title" => "C"}])

    invalid = Item.all.reject(&:valid?)

    assert_equal %w[legacy], invalid.map(&:id)
    assert_match %r{\Aid "legacy" is not unique, it is also used at data/a/items.yml:\d+\z}, invalid.first.errors.full_messages.first
  end

  test "Collection#save! validates the changed and built records only" do
    write_items("a", [{"id" => "one", "title" => ""}, {"id" => "two", "title" => "B"}])
    items = Item.in_file(File.join(@root, "data/a/items.yml"))

    items.find_by(id: "two")["title"] = "Bee"
    assert_nothing_raised { items.save! }

    assert_raises(Yerba::Record::RecordInvalid) { items.create(id: "three") }
  end

  test "validate_all returns the errors of every record" do
    write_items("a", [{"id" => "one"}, {"id" => "one", "title" => "B"}])

    errors = Yerba::Record.validate_all([Item])

    assert_equal 3, errors.size
    assert(errors.all? { |error| error.base.is_a?(Item) })
  end

  private

  def write_conference(attributes = {})
    attributes = {"id" => "conf-2025", "title" => "Conf 2025", "kind" => "conference", "location" => "Bern", "status" => "planned"}.merge(attributes).compact
    path = File.join(@root, "data/conf/conf-2025/conference.yml")
    FileUtils.mkdir_p(File.dirname(path))
    Yerba::Document.from(attributes).save_to!(path)

    Conference.all.first
  end

  def write_items(event_id, items)
    path = File.join(@root, "data", event_id, "items.yml")
    FileUtils.mkdir_p(File.dirname(path))
    Yerba::Document.from(items).save_to!(path)
  end
end
