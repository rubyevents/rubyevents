require "test_helper"

class StickerTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test ".for_user returns every sticker for each event the user attended" do
    @user.event_participations.create!(event: events(:railsconf_2025), attended_as: :visitor)
    @user.event_participations.create!(event: events(:rails_world_2023), attended_as: :visitor)

    slug_counts = Sticker.for_user(@user).map(&:event_slug).tally

    assert_equal({"railsconf-2025" => 2, "rails-world-2023" => 1}, slug_counts)
  end

  test ".for_user accepts an events override" do
    slug_counts = Sticker.for_user(@user, events: [events(:railsconf_2025)]).map(&:event_slug).tally

    assert_equal({"railsconf-2025" => 2}, slug_counts)
  end
end
