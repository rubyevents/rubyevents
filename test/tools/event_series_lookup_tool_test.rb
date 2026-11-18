require "test_helper"

class EventSeriesLookupToolTest < ActiveSupport::TestCase
  include StaticDataSandbox

  test "finds series by name" do
    with_static_data_dir do |dir|
      write_series(dir, "lrug",
        name: "London Ruby User Group",
        kind: "meetup",
        website: "https://lrug.org",
        twitter: "lrug",
        language: "English")

      result = build_tool.execute(query: "London Ruby User Group")

      assert_equal 1, result.size
      assert_equal "lrug", result.first[:slug]
      assert_equal "London Ruby User Group", result.first[:name]
    end
  end

  test "finds series by slug" do
    with_static_data_dir do |dir|
      write_series(dir, "rails-world",
        name: "Rails World",
        kind: "conference",
        website: "https://railsworld.com",
        language: "English")

      result = build_tool.execute(query: "rails-world")

      assert_equal 1, result.size
      assert_equal "rails-world", result.first[:slug]
      assert_equal "Rails World", result.first[:name]
    end
  end

  test "finds series by kind" do
    with_static_data_dir do |dir|
      write_series(dir, "lrug",
        name: "London Ruby User Group",
        kind: "meetup",
        website: "https://lrug.org",
        language: "English")
      write_series(dir, "polish-ruby-user-group",
        name: "Polish Ruby User Group",
        kind: "meetup",
        website: "https://polishruby.org",
        language: "Polish")

      result = build_tool.execute(query: "meetup")

      assert_equal 2, result.size
      assert_includes result.map { |r| r[:slug] }, "lrug"
      assert_includes result.map { |r| r[:slug] }, "polish-ruby-user-group"
    end
  end

  test "case insensitive search" do
    with_static_data_dir do |dir|
      write_series(dir, "lrug", name: "London Ruby User Group", kind: "meetup")

      result = build_tool.execute(query: "lrug")

      assert_equal 1, result.size
      assert_equal "lrug", result.first[:slug]
    end
  end

  test "returns empty array when no matches" do
    with_static_data_dir do |dir|
      write_series(dir, "lrug", name: "London Ruby User Group", kind: "meetup")

      result = build_tool.execute(query: "nonexistent")

      assert_equal [], result
    end
  end

  test "returns multiple matches for partial query" do
    with_static_data_dir do |dir|
      write_series(dir, "lrug",
        name: "London Ruby User Group",
        kind: "meetup",
        language: "English")
      write_series(dir, "polish-ruby-user-group",
        name: "Polish Ruby User Group",
        kind: "meetup",
        language: "Polish")

      result = build_tool.execute(query: "ruby")

      assert result.size > 1
      assert_includes result.map { |r| r[:slug] }, "lrug"
      assert_includes result.map { |r| r[:slug] }, "polish-ruby-user-group"
    end
  end

  test "does not include frequency" do
    with_static_data_dir do |dir|
      write_series(dir, "lrug",
        name: "London Ruby User Group",
        kind: "meetup",
        website: "https://lrug.org",
        twitter: "lrug",
        language: "English")

      result = build_tool.execute(query: "lrug")

      assert_equal 1, result.size
      refute result.first.key?(:frequency)
    end
  end

  test "returns expected fields" do
    with_static_data_dir do |dir|
      write_series(dir, "lrug",
        name: "London Ruby User Group",
        kind: "meetup",
        website: "https://lrug.org",
        twitter: "lrug",
        language: "English")

      result = build_tool.execute(query: "lrug")

      assert_equal 1, result.size
      series = result.first

      assert_equal "lrug", series[:slug]
      assert_equal "London Ruby User Group", series[:name]
      assert_equal "meetup", series[:kind]
      assert_equal "https://lrug.org", series[:website]
      assert_equal "lrug", series[:twitter]
      assert_equal "English", series[:language]
      assert_equal [], series[:youtube_channels]
      assert series.key?(:events_count)
      assert series.key?(:data_path)
    end
  end

  private

  def build_tool
    EventSeriesLookupTool.new
  end

  def write_series(dir, id, attributes)
    path = File.join(dir, "data", id, "series.yml")
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, Yerba::Document.from({"id" => id}.merge(attributes)).to_s)
  end
end
