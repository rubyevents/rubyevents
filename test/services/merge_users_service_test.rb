require "test_helper"

class MergeUsersServiceTest < ActiveSupport::TestCase
  setup do
    @user_to_keep = User.create!(name: "Canonical User", github_handle: "canonical-merge-test")
    @user_to_merge = User.create!(name: "Duplicate User", github_handle: "duplicate-merge-test")
  end

  def merge
    MergeUsersService.new(user_to_keep: @user_to_keep, user_to_merge: @user_to_merge).call
  end

  test "destroys merged user" do
    id = @user_to_merge.id
    merge
    assert_not User.exists?(id)
  end

  test "creates an alias for the merged user's name on user_to_keep" do
    merge
    assert @user_to_keep.aliases.exists?(name: "Duplicate User")
  end

  test "transfers talks to user_to_keep" do
    talk1 = talks(:one)
    talk2 = talks(:two)
    UserTalk.create!(user: @user_to_merge, talk: talk1)
    UserTalk.create!(user: @user_to_merge, talk: talk2)

    merge
    @user_to_keep.reload

    assert_includes @user_to_keep.talks, talk1
    assert_includes @user_to_keep.talks, talk2
  end

  test "does not duplicate talks already on user_to_keep" do
    talk = talks(:one)
    UserTalk.create!(user: @user_to_keep, talk: talk)
    UserTalk.create!(user: @user_to_merge, talk: talk)

    merge
    @user_to_keep.reload

    assert_equal 1, @user_to_keep.user_talks.where(talk: talk).count
  end

  test "transfers event participations to user_to_keep" do
    series = EventSeries.create!(name: "Test Series", slug: "test-series-mus")
    event = Event.create!(name: "Test Event", slug: "test-event-mus", series: series, date: Date.today)
    EventParticipation.create!(user: @user_to_merge, event: event, attended_as: :speaker)

    merge
    @user_to_keep.reload

    assert_equal 1, @user_to_keep.event_participations.where(event: event).count
  end

  test "transfers watched talks to user_to_keep" do
    talk = talks(:one)
    WatchedTalk.create!(user: @user_to_merge, talk: talk, watched: true, watched_at: Time.current)

    merge
    @user_to_keep.reload

    assert @user_to_keep.watched_talks.exists?(talk: talk)
  end

  test "does not duplicate watched talks already on user_to_keep" do
    talk = talks(:one)
    WatchedTalk.create!(user: @user_to_keep, talk: talk, watched: true, watched_at: Time.current)
    WatchedTalk.create!(user: @user_to_merge, talk: talk, watched: true, watched_at: Time.current)

    merge
    @user_to_keep.reload

    assert_equal 1, @user_to_keep.watched_talks.where(talk: talk).count
  end

  test "transfers bookmarks to user_to_keep's watch list" do
    talk = talks(:one)
    watch_list = WatchList.create!(user: @user_to_merge, name: "My List")
    WatchListTalk.create!(watch_list: watch_list, talk: talk)

    merge
    @user_to_keep.reload

    assert @user_to_keep.watch_lists.joins(:watch_list_talks).where(watch_list_talks: {talk: talk}).exists?
  end

  test "transfers favorite_users to user_to_keep" do
    other_user = User.create!(name: "Other User", github_handle: "other-merge-test")
    FavoriteUser.create!(user: @user_to_merge, favorite_user: other_user)

    merge
    @user_to_keep.reload

    assert @user_to_keep.favorite_users.exists?(favorite_user: other_user)
  end

  test "does not create self-referential favorite after merge" do
    FavoriteUser.create!(user: @user_to_merge, favorite_user: @user_to_keep)

    merge
    @user_to_keep.reload

    assert_not @user_to_keep.favorite_users.exists?(favorite_user: @user_to_keep)
  end

  test "transfers favorited_by to user_to_keep" do
    other_user = User.create!(name: "Fan User", github_handle: "fan-merge-test")
    FavoriteUser.create!(user: other_user, favorite_user: @user_to_merge)

    merge
    @user_to_keep.reload

    assert @user_to_keep.favorited_by.exists?(user: other_user)
  end

  test "copies blank profile fields from merged user to user_to_keep" do
    @user_to_merge.update_columns(bio: "Expert Ruby developer", twitter: "duplicate_handle")

    merge
    @user_to_keep.reload

    assert_equal "Expert Ruby developer", @user_to_keep.bio
    assert_equal "duplicate_handle", @user_to_keep.twitter
  end

  test "does not overwrite existing profile fields on user_to_keep" do
    @user_to_keep.update_columns(bio: "Original bio")
    @user_to_merge.update_columns(bio: "Duplicate bio")

    merge
    @user_to_keep.reload

    assert_equal "Original bio", @user_to_keep.bio
  end

  test "copies github_handle from merged user if user_to_keep has none" do
    @user_to_keep.update_columns(github_handle: nil, slug: "canonical-merge-test")
    @user_to_merge.update_columns(github_handle: "duplicate-merge-test")

    merge
    @user_to_keep.reload

    assert_equal "duplicate-merge-test", @user_to_keep.github_handle
  end
end
