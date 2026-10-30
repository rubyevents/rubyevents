require "test_helper"

class Static::StampTest < ActiveSupport::TestCase
  test "missing_for_events counts a country covered by its UK nation stamps" do
    with_stamps("gb-sct.webp", "us.webp") do
      missing = Static::Stamp.missing_for_events.map(&:alpha2)

      assert_not_includes missing, "GB"
      assert_includes missing, "NL"
      assert_not_includes missing, "US"
    end
  end

  test "missing_for_events lists a country without its own or UK nation stamps" do
    with_stamps("us.webp") do
      assert_includes Static::Stamp.missing_for_events.map(&:alpha2), "GB"
    end
  end

  private

  def with_stamps(*files)
    root = Dir.mktmpdir
    stamps = File.join(root, "app/assets/images/stamps")
    FileUtils.mkdir_p(stamps)
    files.each { |file| File.write(File.join(stamps, file), "webp") }

    previous = Static::Stamp.instance_variable_get(:@root)
    Static::Stamp.root = root
    Static::Stamp.unload!

    yield
  ensure
    Static::Stamp.root = previous
    Static::Stamp.unload!
    FileUtils.rm_rf(root)
  end
end
