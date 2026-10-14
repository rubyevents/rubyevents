require "test_helper"

class Yerba::Record::QueryingTest < ActiveSupport::TestCase
  test "where returns matching records" do
    conferences = Static::Event.where(kind: "conference")

    assert conferences.any?
    assert conferences.all? { |event| event.kind == "conference" }
  end

  test "where returns empty for no matches" do
    results = Static::Event.where(kind: "nonexistent")

    assert_empty results
    assert_equal [], results.to_a
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

  test "where and where.not return chainable collections" do
    results = Static::Event.where.not(kind: "conference")

    assert_kind_of Yerba::Record::Collection, results
    assert_kind_of Yerba::Record::Collection, Static::Event.where(kind: "conference")

    meetups = Static::Event.where.not(kind: "conference").where(kind: "meetup")

    assert meetups.any?
    assert meetups.all?(&:meetup?)
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

  test "where matches an association with nested criteria" do
    talks = Static::Talk.where(event: {slug: "rubyconf-2024"})

    assert talks.any?
    assert_equal Static::Event.find_by_slug("rubyconf-2024").talks.map(&:id), talks.map(&:id)
  end

  test "where falls back to the record's method for values that aren't stored" do
    assert_equal Static::Talk.where(event: {slug: "rubyconf-2024"}).map(&:id), Static::Talk.where(event_slug: "rubyconf-2024").map(&:id)
  end

  test "where.not works with association criteria" do
    excluded = Static::Talk.where.not(event: {slug: "rubyconf-2024"})

    assert_equal Static::Talk.count - Static::Talk.where(event_slug: "rubyconf-2024").count, excluded.count
    assert excluded.none? { |talk| talk.event_slug == "rubyconf-2024" }
  end
end
