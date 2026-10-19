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

  test "models derive their files, path params and associations from the pattern" do
    talk = Static::Talk.all.first

    assert_equal "data/*/*/videos.yml", Static::Talk.path_pattern.glob
    assert_equal talk.relative_file_path.split("/").first(2), talk.path_params.values_at(:series_id, :event_id)
    assert_equal talk.path_params[:event_id], talk.event.id
    assert_equal talk.path_params[:series_id], talk.series.id
    assert_includes talk.event.talks.map(&:file_path), talk.file_path
  end
end
