require "test_helper"

class Static::EventSeriesTest < ActiveSupport::TestCase
  include StaticDataSandbox

  test "import_series! moves the series listed in old_ids to the new id" do
    with_series("testrb", old_ids: ["test-rb"]) do |series|
      previous = ::EventSeries.create!(name: "Test.rb", slug: "test-rb", kind: "meetup")

      record = series.import_series!(index: false)

      assert_equal previous.id, record.id
      assert_equal "testrb", record.slug
      assert_nil ::EventSeries.find_by(slug: "test-rb")
      assert_equal record, ::EventSeries.find_by_slug_or_alias("test-rb")
    end
  end

  test "import_series! keeps the old id as an alias when there is no series to move" do
    with_series("testrb", old_ids: ["test-rb"]) do |series|
      record = series.import_series!(index: false)

      assert_equal "testrb", record.slug
      assert_equal record, ::EventSeries.find_by_slug_or_alias("test-rb")
    end
  end

  private

  def with_series(id, old_ids:)
    with_static_data_dir do |dir|
      path = File.join(dir, "data", id, "series.yml")
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, Yerba::Document.from({"id" => id, "old_ids" => old_ids, "name" => "Test.rb", "kind" => "meetup"}).to_s)

      yield Static::EventSeries.find_by_slug(id)
    end
  end
end
