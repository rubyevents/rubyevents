require "test_helper"

class EventSeries::StaticMetadataTest < ActiveSupport::TestCase
  test "instagram returns nil when the YAML does not define it" do
    assert_nil events(:railsconf_2017).series.static_metadata.instagram
  end
end
