require "test_helper"

class Yerba::Record::QueryingTest < ActiveSupport::TestCase
  test "where returns matching records" do
    conferences = Static::Event.where(kind: "conference")

    assert conferences.any?
    assert conferences.all? { |event| event.kind == "conference" }
  end

  test "where returns empty for no matches" do
    results = Static::Event.where(kind: "nonexistent")

    assert_equal [], results
  end

  test "where.not excludes matching records" do
    results = Static::Event.where.not(kind: "conference")

    assert results.any?
    assert results.none? { |event| event.kind == "conference" }
  end

  test "where.not with nil excludes records without the field" do
    results = Static::Event.where.not(featured_background: nil)

    assert results.any?
    assert results.all? { |event| event.featured_background.present? }
  end

  test "where.not returns a RecordCollection" do
    results = Static::Event.where.not(kind: "conference")

    assert_instance_of Yerba::Record::RecordCollection, results
  end

  test "where.not supports chaining pluck" do
    slugs = Static::Event.where.not(featured_background: nil).pluck(:slug)

    assert slugs.any?
    assert slugs.all? { |slug| slug.is_a?(String) }
  end

  test "find_by returns matching record" do
    event = Static::Event.find_by_slug("rubyconf-2026")

    assert_not_nil event
    assert_equal "RubyConf 2026", event.title
  end

  test "pluck returns field values" do
    names = Static::EventSeries.pluck("name")

    assert names.any?
    assert_includes names, "RubyConf"
  end

  test "count returns total records" do
    assert Static::Event.count > 0
    assert Static::EventSeries.count > 0
  end

  test "first and last return records" do
    assert_not_nil Static::Event.first
    assert_not_nil Static::Event.last
  end
end
