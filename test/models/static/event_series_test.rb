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

  test "import_series! skips an old id whose slug another alias already uses" do
    with_series("testrb", old_ids: ["test-rb"]) do |series|
      events(:future_conference).slug_aliases.create!(name: "test-rb", slug: "test-rb")

      record = series.import_series!(index: false)

      assert_equal "testrb", record.slug
      assert_empty record.aliases.where(slug: "test-rb")
    end
  end

  test "a nested series without default images uses its parent's" do
    with_nested_series do |root, parent, child|
      banner = File.join(root, "app/assets/images/events/test-group/default/banner.webp")
      FileUtils.mkdir_p(File.dirname(banner))
      File.write(banner, "")

      assert_equal Pathname.new(banner), parent.default_image("banner.webp")
      assert_equal Pathname.new(banner), child.default_image("banner.webp")
      assert_nil child.default_image("avatar.webp")
    end
  end

  test "a nested series keeps its own default images over its parent's" do
    with_nested_series do |root, _parent, child|
      %w[test-group test-chapter].each do |id|
        path = File.join(root, "app/assets/images/events/#{id}/default/banner.webp")
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, "")
      end

      assert_equal Pathname.new(File.join(root, "app/assets/images/events/test-chapter/default/banner.webp")), child.default_image("banner.webp")
    end
  end

  test "a nested series uses its parent's colors unless it has its own" do
    with_nested_series(child_attributes: {"featured_color" => "#000000"}) do |_root, _parent, child|
      assert_equal "#DC390B", child.banner_background
      assert_equal "#DC390B", child.featured_background
      assert_equal "#000000", child.featured_color
    end
  end

  private

  def with_nested_series(child_attributes: {})
    with_static_data_dir do |dir|
      parent_path = File.join(dir, "data", "test-group", "series.yml")
      child_path = File.join(dir, "data", "test-group", "test-chapter", "series.yml")
      FileUtils.mkdir_p(File.dirname(child_path))
      File.write(parent_path, Yerba::Document.from({"id" => "test-group", "name" => "Test Group", "kind" => "organisation",
        "banner_background" => "#DC390B", "featured_background" => "#DC390B", "featured_color" => "#FFFFFF"}).to_s)
      File.write(child_path, Yerba::Document.from({"id" => "test-chapter", "name" => "Test Chapter", "kind" => "workshop"}.merge(child_attributes)).to_s)

      yield dir, Static::EventSeries.find_by_slug("test-group"), Static::EventSeries.find_by_slug("test-chapter")
    end
  end

  def with_series(id, old_ids:)
    with_static_data_dir do |dir|
      path = File.join(dir, "data", id, "series.yml")
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, Yerba::Document.from({"id" => id, "old_ids" => old_ids, "name" => "Test.rb", "kind" => "meetup"}).to_s)

      yield Static::EventSeries.find_by_slug(id)
    end
  end
end
