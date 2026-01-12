# rubocop:disable Layout/LineLength
# == Schema Information
#
# Table name: events
#
#  id              :integer          not null, primary key
#  date            :date
#  city            :string
#  country_code    :string
#  organisation_id :integer          not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  name            :string           default(""), not null
#  slug            :string           default(""), not null
#
# rubocop:enable Layout/LineLength
require "test_helper"

class YouTube::VideoMetadataRailsWorldTest < ActiveSupport::TestCase
  test "remove the event name from the title and preserve the keynote mention" do
    metadata = OpenStruct.new({
      title: "Nikita Vasilevsky - Implementing Native Composite Primary Key Support in Rails 7.1 - Rails World '23",
      description: "RailsWorld 2023 lorem ipsum"
    })
    results = YouTube::VideoMetadataRailsWorld.new(metadata: metadata, event_name: "Rails World 23")
    assert_equal results.cleaned.title, "Implementing Native Composite Primary Key Support in Rails 7.1"
    refute results.keynote?
  end
end
