require "test_helper"

class Static::StickerTest < ActiveSupport::TestCase
  include StaticDataSandbox

  setup do
    @user = users(:one)
  end

  test ".for_user returns every sticker for each event the user attended" do
    @user.event_participations.create!(event: events(:railsconf_2025), role: :attendee)
    @user.event_participations.create!(event: events(:rails_world_2023), role: :attendee)

    event_counts = Static::Sticker.for_user(@user).map(&:event_id).tally

    assert_equal({"railsconf-2025" => 2, "rails-world-2023" => 1}, event_counts)
  end

  test ".for_user accepts an events override" do
    event_counts = Static::Sticker.for_user(@user, events: [events(:railsconf_2025)]).map(&:event_id).tally

    assert_equal({"railsconf-2025" => 2}, event_counts)
  end

  test "a sticker reads its event, code, name and image path from its file" do
    sticker = Static::Event.find_by_slug("railsconf-2025").stickers.find { |record| record.variant == "alt" }

    assert_equal({series_id: "railsconf", event_id: "railsconf-2025"}, sticker.path_params)
    assert_equal "railsconf-2025", sticker.event.id
    assert_equal "railsconf", sticker.series.id
    assert_equal "RAILSCONF-2025-STICKER-ALT", sticker.code
    assert_equal "#{sticker.event.title} (Sticker Alt)", sticker.name
    assert_equal "events/railsconf/railsconf-2025/sticker-alt.webp", sticker.image_path
  end

  test "all, where and find_by work on the sticker files" do
    assert Static::Sticker.all.count > 50
    assert_equal %w[railsconf-2025], Static::Sticker.where(event_id: "railsconf-2025").map(&:event_id).uniq
    assert_equal "railsconf", Static::Sticker.find_by(event_id: "railsconf-2025").series_id
  end

  test "saving a changed segment moves the sticker file" do
    with_static_data_dir do |root|
      FileUtils.mkdir_p(File.join(root, "app/assets/images/events/testconf/testconf-2024"))
      File.write(File.join(root, "app/assets/images/events/testconf/testconf-2024/sticker-1.webp"), "webp")

      sticker = Static::Sticker.all.first
      assert_equal "testconf-2024", sticker.event_id

      sticker.event_id = "testconf-2025"
      sticker.save!

      assert_equal "testconf-2025", sticker.event_id
      assert File.exist?(File.join(root, "app/assets/images/events/testconf/testconf-2025/sticker-1.webp"))
      assert_not File.exist?(File.join(root, "app/assets/images/events/testconf/testconf-2024/sticker-1.webp"))
    end
  end
end
