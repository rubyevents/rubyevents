require "test_helper"

class Yerba::Record::PathPatternTest < ActiveSupport::TestCase
  PATTERN = Yerba::Record::PathPattern.new("data/:series_id/:id/event.yml")

  test "names, prefix and glob" do
    assert_equal %i[series_id id], PATTERN.names
    assert_equal "data", PATTERN.prefix
    assert_equal "data/*/*/event.yml", PATTERN.glob
    assert PATTERN.dynamic?
    assert_not Yerba::Record::PathPattern.new("data/speakers.yml").dynamic?
  end

  test "match reads the named segments from the end of a path" do
    assert_equal({series_id: "rubyconf", id: "rubyconf-2024"}, PATTERN.match("/app/data/rubyconf/rubyconf-2024/event.yml"))
    assert_equal({series_id: "rubyconf", id: "rubyconf-2024"}, PATTERN.match("data/rubyconf/rubyconf-2024/event.yml"))
    assert_nil PATTERN.match("/app/data/rubyconf/rubyconf-2024/videos.yml")
    assert_nil PATTERN.match("/app/data/rubyconf/event.yml")
  end

  test "root_of is the directory the pattern starts in" do
    assert_equal "/app", PATTERN.root_of("/app/data/rubyconf/rubyconf-2024/event.yml")
    assert_equal ".", PATTERN.root_of("data/rubyconf/rubyconf-2024/event.yml")
    assert_nil PATTERN.root_of("/app/rubyconf-2024/event.yml")
  end

  test "expand fills in the named segments" do
    assert_equal "data/rubyconf/rubyconf-2024/event.yml", PATTERN.expand(series_id: "rubyconf", id: "rubyconf-2024")
    assert_nil PATTERN.expand(series_id: "rubyconf")
  end

  test "a double star matches any number of directories" do
    pattern = Yerba::Record::PathPattern.new("data/:series_id/**/event.yml")

    assert_equal({series_id: "rubyconf"}, pattern.match("/app/data/rubyconf/2024/event.yml"))
    assert_equal({series_id: "rubyconf"}, pattern.match("/app/data/rubyconf/editions/2024/event.yml"))
    assert_nil pattern.expand(series_id: "rubyconf")
  end

  test "a splat segment captures any number of directories under a name" do
    pattern = Yerba::Record::PathPattern.new("data/*parent_path/:series_id/:id/event.yml")

    assert_equal %i[parent_path series_id id], pattern.names
    assert_equal "data", pattern.prefix
    assert_equal "data/**/*/*/event.yml", pattern.glob
    assert_not pattern.wildcard?

    assert_equal({series_id: "lrug", id: "2020-01-14"}, pattern.match("/app/data/lrug/2020-01-14/event.yml"))
    assert_equal({parent_path: "rails-girls", series_id: "rails-girls-bern", id: "2024-03-01"}, pattern.match("/app/data/rails-girls/rails-girls-bern/2024-03-01/event.yml"))
    assert_equal({parent_path: "a/b", series_id: "c", id: "d"}, pattern.match("data/a/b/c/d/event.yml"))
    assert_equal "/app", pattern.root_of("/app/data/rails-girls/rails-girls-bern/2024-03-01/event.yml")
  end

  test "a splat segment expands to its directories, or to nothing when blank" do
    pattern = Yerba::Record::PathPattern.new("data/*parent_path/:id/series.yml")

    assert_equal "data/lrug/series.yml", pattern.expand(id: "lrug")
    assert_equal "data/lrug/series.yml", pattern.expand(parent_path: nil, id: "lrug")
    assert_equal "data/rails-girls/rails-girls-bern/series.yml", pattern.expand(parent_path: "rails-girls", id: "rails-girls-bern")
    assert_equal "data/a/b/c/series.yml", pattern.expand(parent_path: "a/b", id: "c")
    assert_equal "data/rails-girls/rails-girls-bern", pattern.expand_through(:id, parent_path: "rails-girls", id: "rails-girls-bern")
  end

  test "a splat segment rewrites to a new parent path" do
    pattern = Yerba::Record::PathPattern.new("data/*parent_path/:id/series.yml")

    assert_equal "/app/data/rails-girls/rails-girls-bern/series.yml", pattern.rewrite("/app/data/rails-girls-bern/series.yml", {parent_path: "rails-girls"})
    assert_equal "/app/data/rails-girls-bern/series.yml", pattern.rewrite("/app/data/rails-girls/rails-girls-bern/series.yml", {parent_path: nil})
  end

  test "models derive their files, path params and associations from the pattern" do
    talk = Static::Talk.all.first

    assert_equal "data/**/*/*/videos.yml", Static::Talk.path_pattern.glob
    assert_equal talk.relative_file_path.split("/")[-3, 2], talk.path_params.values_at(:series_id, :event_id)
    assert_equal talk.path_params[:event_id], talk.event.id
    assert_equal talk.path_params[:series_id], talk.series.id
    assert_includes talk.event.talks.map(&:file_path), talk.file_path
  end
end
