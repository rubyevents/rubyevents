require "test_helper"

class User::MergerTest < ActiveSupport::TestCase
  setup do
    @user_to_keep = User.create!(name: "Canonical User", github_handle: "canonical-merge-test")
    @user_to_merge = User.create!(name: "Duplicate User", github_handle: "duplicate-merge-test")
  end

  def merge
    @user_to_keep.merge_with!(@user_to_merge)
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

  test "transfers existing aliases from merged user to user_to_keep" do
    Alias.create!(aliasable: @user_to_merge, name: "Old Name", slug: "old-name")

    merge
    @user_to_keep.reload

    assert @user_to_keep.aliases.exists?(name: "Old Name", slug: "old-name")
  end

  test "does not fail when merged user has aliases" do
    Alias.create!(aliasable: @user_to_merge, name: "Old Alias", slug: "old-alias")

    merge
    @user_to_keep.reload

    assert @user_to_keep.aliases.exists?(slug: "old-alias")
    assert @user_to_keep.aliases.exists?(name: "Duplicate User")
  end

  test "transfers multiple aliases from merged user" do
    Alias.create!(aliasable: @user_to_merge, name: "Alias One", slug: "alias-one")
    Alias.create!(aliasable: @user_to_merge, name: "Alias Two", slug: "alias-two")

    merge
    @user_to_keep.reload

    assert @user_to_keep.aliases.exists?(slug: "alias-one")
    assert @user_to_keep.aliases.exists?(slug: "alias-two")
    assert @user_to_keep.aliases.exists?(name: "Duplicate User")
  end

  test "transfers connected accounts to user_to_keep" do
    ConnectedAccount.create!(user: @user_to_merge, provider: "github", username: "duplicate-merge-test")

    merge
    @user_to_keep.reload

    assert @user_to_keep.connected_accounts.exists?(provider: "github", username: "duplicate-merge-test")
  end

  test "transfers different connected accounts from merged user" do
    ConnectedAccount.create!(user: @user_to_keep, provider: "github", username: "canonical-account")
    ConnectedAccount.create!(user: @user_to_merge, provider: "github", username: "duplicate-account")

    merge
    @user_to_keep.reload

    assert @user_to_keep.connected_accounts.exists?(provider: "github", username: "canonical-account")
    assert @user_to_keep.connected_accounts.exists?(provider: "github", username: "duplicate-account")
  end

  test "transfers passport connected accounts" do
    ConnectedAccount.create!(user: @user_to_merge, provider: "passport", username: "passport-123")

    merge
    @user_to_keep.reload

    assert @user_to_keep.connected_accounts.exists?(provider: "passport", username: "passport-123")
  end

  test "transfers event involvements to user_to_keep" do
    series = EventSeries.create!(name: "Test Series", slug: "test-series-inv")
    event = Event.create!(name: "Test Event", slug: "test-event-inv", series: series, date: Date.today)
    EventInvolvement.create!(involvementable: @user_to_merge, event: event, role: "organizer")

    merge
    @user_to_keep.reload

    assert @user_to_keep.event_involvements.exists?(event: event, role: "organizer")
  end

  test "does not duplicate event involvements already on user_to_keep" do
    series = EventSeries.create!(name: "Test Series", slug: "test-series-inv2")
    event = Event.create!(name: "Test Event", slug: "test-event-inv2", series: series, date: Date.today)
    EventInvolvement.create!(involvementable: @user_to_keep, event: event, role: "organizer")
    EventInvolvement.create!(involvementable: @user_to_merge, event: event, role: "organizer")

    merge
    @user_to_keep.reload

    assert_equal 1, @user_to_keep.event_involvements.where(event: event, role: "organizer").count
  end

  test "does not duplicate bookmarks already on user_to_keep's watch list" do
    talk = talks(:one)
    keep_list = WatchList.create!(user: @user_to_keep, name: "Default")
    WatchListTalk.create!(watch_list: keep_list, talk: talk)

    merge_list = WatchList.create!(user: @user_to_merge, name: "My List")
    WatchListTalk.create!(watch_list: merge_list, talk: talk)

    merge
    @user_to_keep.reload

    assert_equal 1, keep_list.reload.watch_list_talks.where(talk: talk).count
    assert_not WatchList.exists?(merge_list.id)
  end

  test "destroys merged user's empty watch lists after transferring bookmarks" do
    merge_list = WatchList.create!(user: @user_to_merge, name: "Empty List")

    merge

    assert_not WatchList.exists?(merge_list.id)
  end

  test "does not duplicate event participations already on user_to_keep" do
    series = EventSeries.create!(name: "Test Series", slug: "test-series-ep")
    event = Event.create!(name: "Test Event", slug: "test-event-ep", series: series, date: Date.today)
    EventParticipation.create!(user: @user_to_keep, event: event, attended_as: :speaker)
    EventParticipation.create!(user: @user_to_merge, event: event, attended_as: :speaker)

    merge
    @user_to_keep.reload

    assert_equal 1, @user_to_keep.event_participations.where(event: event, attended_as: :speaker).count
  end

  test "does not duplicate favorite_users already on user_to_keep" do
    other_user = User.create!(name: "Other User", github_handle: "other-fav-merge")
    FavoriteUser.create!(user: @user_to_keep, favorite_user: other_user)
    FavoriteUser.create!(user: @user_to_merge, favorite_user: other_user)

    merge
    @user_to_keep.reload

    assert_equal 1, @user_to_keep.favorite_users.where(favorite_user: other_user).count
  end

  test "does not delete merged user if transaction fails" do
    talk = talks(:one)
    UserTalk.create!(user: @user_to_merge, talk: talk)

    @user_to_keep.merger.define_singleton_method(:merge_profile_fields) do
      raise ActiveRecord::RecordInvalid.new(@user_to_keep)
    end

    assert_raises(ActiveRecord::RecordInvalid) { merge }

    assert User.exists?(@user_to_merge.id)
    assert @user_to_merge.user_talks.exists?(talk: talk)
  end

  test "skips alias creation when merged user has blank name" do
    @user_to_merge.update_columns(name: "")

    merge
    @user_to_keep.reload

    assert_equal 0, @user_to_keep.aliases.where(name: "").count
  end

  test "skips alias creation when merged user has blank slug" do
    @user_to_merge.update_columns(slug: "")

    merge
    @user_to_keep.reload

    assert_not @user_to_keep.aliases.exists?(slug: "")
  end
end
