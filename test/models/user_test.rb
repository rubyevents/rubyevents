require "test_helper"

class UserTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "can create a user with just a name" do
    user = User.create!(name: "John Doe")
    assert_equal "john-doe", user.slug
  end

  test "the slug provided is used" do
    user = User.create!(name: "John Doe", slug: "john-doe-2")
    assert_equal "john-doe-2", user.slug
  end

  test "not downcasing github_handle" do
    user = User.create!(name: "John Doe", github_handle: "TEKIN")
    assert_equal "TEKIN", user.github_handle
    assert_equal "tekin", user.slug
  end

  test "should normalize github_handle by stripping URL, www, and @" do
    user = users(:one)

    user.github_handle = "Https://www.github.com/tekin"
    user.save
    assert_equal "tekin", user.github_handle

    user.github_handle = "github.com/tekin"
    user.save
    assert_equal "tekin", user.github_handle

    user.github_handle = "@tekin"
    user.save
    assert_equal "tekin", user.github_handle
  end

  test "find_by_name_or_alias finds user by exact name" do
    user = User.create!(name: "Yukihiro Matsumoto", github_handle: "matz-test-1")

    found_user = User.find_by_name_or_alias("Yukihiro Matsumoto")
    assert_equal user.id, found_user.id
  end

  test "find_by_name_or_alias finds user by alias name" do
    user = User.create!(name: "Yukihiro Matsumoto", github_handle: "matz-test-2")
    user.aliases.create!(name: "Matz", slug: "matz-alias-test")

    found_user = User.find_by_name_or_alias("Matz")
    assert_equal user.id, found_user.id
  end

  test "find_by_name_or_alias returns nil for non-existent name" do
    found_user = User.find_by_name_or_alias("Nonexistent Person")
    assert_nil found_user
  end

  test "find_by_name_or_alias returns nil for blank name" do
    assert_nil User.find_by_name_or_alias("")
    assert_nil User.find_by_name_or_alias(nil)
  end

  test "find_by_name_or_alias prioritizes exact name match over alias" do
    user1 = User.create!(name: "John Doe", github_handle: "john-test-1")
    user2 = User.create!(name: "Jane Doe", github_handle: "jane-test-1")
    user2.aliases.create!(name: "John Doe", slug: "john-doe-alias")

    found_user = User.find_by_name_or_alias("John Doe")
    assert_equal user1.id, found_user.id
  end

  test "assign_canonical_user! marks user for deletion" do
    user = User.create!(name: "Duplicate User", github_handle: "duplicate-test")
    canonical_user = User.create!(name: "Canonical User", github_handle: "canonical-test")

    assert_equal false, user.marked_for_deletion

    user.assign_canonical_user!(canonical_user: canonical_user)
    user.reload

    assert_equal true, user.marked_for_deletion
    assert_equal canonical_user, user.canonical
  end

  test "assign_canonical_user! creates an alias on the canonical user" do
    user = User.create!(name: "Old Name", github_handle: "old-name-test")
    canonical_user = User.create!(name: "New Name", github_handle: "new-name-test")

    user.assign_canonical_user!(canonical_user: canonical_user)

    alias_record = canonical_user.aliases.find_by(name: "Old Name")
    assert_not_nil alias_record
    assert_equal "old-name-test", alias_record.slug
  end

  test "marked_for_deletion scope returns only marked users" do
    user1 = User.create!(name: "User 1", github_handle: "user-1-marked", marked_for_deletion: true)
    user2 = User.create!(name: "User 2", github_handle: "user-2-not-marked", marked_for_deletion: false)

    marked_users = User.marked_for_deletion
    assert_includes marked_users, user1
    assert_not_includes marked_users, user2
  end

  test "find_by_slug_or_alias finds user by slug" do
    user = User.create!(name: "Test User", github_handle: "test-slug-user")

    found_user = User.find_by_slug_or_alias(user.slug)
    assert_equal user.id, found_user.id
  end

  test "find_by_slug_or_alias finds user by alias slug" do
    user = User.create!(name: "Primary User", github_handle: "primary-slug-user")
    user.aliases.create!(name: "Old Name", slug: "old-slug")

    found_user = User.find_by_slug_or_alias("old-slug")
    assert_equal user.id, found_user.id
  end

  test "find_by_slug_or_alias returns nil for non-existent slug" do
    found_user = User.find_by_slug_or_alias("nonexistent-slug")
    assert_nil found_user
  end

  test "find_by_slug_or_alias returns nil for blank slug" do
    assert_nil User.find_by_slug_or_alias("")
    assert_nil User.find_by_slug_or_alias(nil)
  end

  test "find_by_slug_or_alias prioritizes slug over alias" do
    user1 = User.create!(name: "User One", github_handle: "user-one-slug")
    user2 = User.create!(name: "User Two", github_handle: "user-two-slug")
    user2.aliases.create!(name: "Alias", slug: user1.slug)

    found_user = User.find_by_slug_or_alias(user1.slug)
    assert_equal user1.id, found_user.id
  end

  test "assign_canonical_user! reassigns all user talks" do
    user = User.create!(name: "Speaker", github_handle: "speaker-talks")
    canonical_user = User.create!(name: "Canonical Speaker", github_handle: "canonical-talks")
    talk1 = talks(:one)
    talk2 = talks(:two)

    UserTalk.create!(user: user, talk: talk1)
    UserTalk.create!(user: user, talk: talk2)

    assert_equal 2, user.talks.count
    assert_equal 0, canonical_user.talks.count

    user.assign_canonical_user!(canonical_user: canonical_user)
    user.reload
    canonical_user.reload

    assert_equal 0, user.talks.count
    assert_equal 2, canonical_user.talks.count

    assert_includes canonical_user.talks, talk1
    assert_includes canonical_user.talks, talk2
  end

  test "assign_canonical_user! reassigns event participations" do
    user = User.create!(name: "Participant", github_handle: "participant-events")
    canonical_user = User.create!(name: "Canonical Participant", github_handle: "canonical-events")
    series = EventSeries.create!(name: "Test Series", slug: "test-series")
    event = Event.create!(name: "Test Event", slug: "test-event", series: series, date: Date.today)

    EventParticipation.create!(user: user, event: event, attended_as: :speaker)

    assert_equal 1, user.event_participations.count
    assert_equal 0, canonical_user.event_participations.count

    user.assign_canonical_user!(canonical_user: canonical_user)
    user.reload
    canonical_user.reload

    assert_equal 0, user.event_participations.count
    assert_equal 1, canonical_user.event_participations.count
    assert_equal event, canonical_user.participated_events.first
  end

  test "assign_canonical_user! preserves event participation attributes" do
    user = User.create!(name: "Keynote Speaker", github_handle: "keynote-speaker")
    canonical_user = User.create!(name: "Canonical Keynote", github_handle: "canonical-keynote")
    series = EventSeries.create!(name: "Test seriesAttrs", slug: "test-org-attrs")
    event = Event.create!(name: "Test Event Attrs", slug: "test-event-attrs", series: series, date: Date.today)

    EventParticipation.create!(
      user: user,
      event: event,
      attended_as: :keynote_speaker
    )

    user.assign_canonical_user!(canonical_user: canonical_user)
    canonical_user.reload

    new_participation = canonical_user.event_participations.first
    assert_not_nil new_participation
    assert_equal "keynote_speaker", new_participation.attended_as
    assert_equal event.id, new_participation.event_id
  end

  test "assign_canonical_user! reassigns event involvements" do
    user = User.create!(name: "Organizer", github_handle: "organizer-events")
    canonical_user = User.create!(name: "Canonical Organizer", github_handle: "canonical-organizer")
    series = EventSeries.create!(name: "Test series2", slug: "test-org-2")
    event = Event.create!(name: "Test Event 2", slug: "test-event-2", series: series, date: Date.today)

    EventInvolvement.create!(involvementable: user, event: event, role: :organizer, position: 1)

    assert_equal 1, user.event_involvements.count
    assert_equal 0, canonical_user.event_involvements.count

    user.assign_canonical_user!(canonical_user: canonical_user)
    user.reload
    canonical_user.reload

    assert_equal 0, user.event_involvements.count
    assert_equal 1, canonical_user.event_involvements.count
    assert_equal event, canonical_user.involved_events.first
  end

  test "assign_canonical_user! preserves event involvement attributes" do
    user = User.create!(name: "MC", github_handle: "mc-host")
    canonical_user = User.create!(name: "Canonical MC", github_handle: "canonical-mc")
    series = EventSeries.create!(name: "Test Series", slug: "test-series")
    event = Event.create!(name: "Test Event Involvement", slug: "test-event-involvement", series: series, date: Date.today)

    EventInvolvement.create!(
      involvementable: user,
      event: event,
      role: :mc,
      position: 5
    )

    user.assign_canonical_user!(canonical_user: canonical_user)
    canonical_user.reload

    new_involvement = canonical_user.event_involvements.first
    assert_not_nil new_involvement
    assert_equal "mc", new_involvement.role
    assert_equal 5, new_involvement.position
    assert_equal event.id, new_involvement.event_id
  end

  test "assign_canonical_speaker! calls assign_canonical_user!" do
    user = User.create!(name: "Old Method User", github_handle: "old-method")
    canonical_user = User.create!(name: "Canonical", github_handle: "canonical-old")

    user.assign_canonical_speaker!(canonical_speaker: canonical_user)
    user.reload

    assert_equal true, user.marked_for_deletion
    assert_equal canonical_user, user.canonical
    assert_not_nil canonical_user.aliases.find_by(name: "Old Method User")
  end

  test "find_by_name_or_alias excludes users marked for deletion" do
    user = User.create!(name: "Marked User", github_handle: "marked-for-deletion-test")
    user.update_column(:marked_for_deletion, true)

    found_user = User.find_by_name_or_alias("Marked User")
    assert_nil found_user
  end

  test "find_by_name_or_alias finds alias even if original user is marked for deletion" do
    canonical_user = User.create!(name: "Canonical User", github_handle: "canonical-marked-test")
    marked_user = User.create!(name: "Duplicate User", github_handle: "duplicate-marked-test")

    marked_user.assign_canonical_user!(canonical_user: canonical_user)
    marked_user.reload

    alias_record = Alias.find_by(aliasable_type: "User", name: "Duplicate User")
    assert_not_nil alias_record
    assert_equal canonical_user.id, alias_record.aliasable_id

    found_via_alias = User.find_by_name_or_alias("Duplicate User")
    assert_equal canonical_user.id, found_via_alias.id
  end

  test "find_by_slug_or_alias excludes users marked for deletion" do
    user = User.create!(name: "Slug Marked User", github_handle: "slug-marked-test")
    original_slug = user.slug
    user.update_column(:marked_for_deletion, true)

    found_user = User.find_by_slug_or_alias(original_slug)
    assert_nil found_user
  end

  test "find_by_slug_or_alias finds alias even if original user is marked for deletion" do
    canonical_user = User.create!(name: "Canonical Slug User", github_handle: "canonical-slug-marked")
    marked_user = User.create!(name: "Duplicate Slug User", github_handle: "duplicate-slug-marked")
    original_slug = marked_user.slug

    marked_user.assign_canonical_user!(canonical_user: canonical_user)
    marked_user.reload

    alias_record = Alias.find_by(aliasable_type: "User", slug: original_slug)
    assert_not_nil alias_record
    assert_equal canonical_user.id, alias_record.aliasable_id

    found_user = User.find_by_slug_or_alias(original_slug)
    assert_equal canonical_user.id, found_user.id
  end

  test "updating location enqueues geocoding job" do
    user = User.create!(name: "Geo User", github_handle: "geo-user")

    assert_enqueued_with(job: GeocodeRecordJob) do
      user.update!(location: "Berlin, Germany")
    end
  end

  test "updating location does not enqueue job when location unchanged" do
    user = User.create!(name: "Geo User 2", github_handle: "geo-user-2", location: "Berlin, Germany")

    assert_no_enqueued_jobs(only: GeocodeRecordJob) do
      user.update!(name: "New Name")
    end
  end

  test "country returns Country object when country_code present" do
    user = User.create!(name: "Test User", country_code: "US")

    assert_not_nil user.country
    assert_equal "US", user.country.alpha2
    assert_equal "United States", user.country.name
  end

  test "country returns Country object for different country codes" do
    user = User.create!(name: "Test User", country_code: "DE")

    assert_not_nil user.country
    assert_equal "DE", user.country.alpha2
    assert_equal "Germany", user.country.name
  end

  test "country returns nil when country_code is blank" do
    user = User.create!(name: "Test User", country_code: "")

    assert_nil user.country
  end

  test "country returns nil when country_code is nil" do
    user = User.create!(name: "Test User", country_code: nil)

    assert_nil user.country
  end

  test "meta_description returns generic profile description for user with no talks" do
    user = User.create!(name: "No Talks User", github_handle: "no-talks-user", talks_count: 0)

    assert_equal "No Talks User's profile on RubyEvents.org", user.meta_description
  end

  test "meta_description returns fallback topic text for user with talks but no topics" do
    user = User.create!(name: "Speaker No Topics", github_handle: "speaker-no-topics")
    talk = talks(:one)

    UserTalk.create!(user: user, talk: talk)
    user.update_column(:talks_count, 1)

    talk.talk_topics.destroy_all

    expected = "Discover all the talks given by Speaker No Topics on subjects related to Ruby language and Ruby Frameworks such as Rails, Hanami and others."
    assert_equal expected, user.meta_description
  end

  test "meta_description includes top topics for user with talks and topics" do
    user = User.create!(name: "Speaker With Topics", github_handle: "speaker-with-topics")

    talk1 = talks(:one)
    talk2 = talks(:two)

    UserTalk.create!(user: user, talk: talk1)
    UserTalk.create!(user: user, talk: talk2)
    user.update_column(:talks_count, 2)

    topic_rails = Topic.create!(name: "Rails", slug: "rails", status: "approved")
    topic_ruby = Topic.create!(name: "Ruby", slug: "ruby", status: "approved")

    talk1.talk_topics.destroy_all
    talk2.talk_topics.destroy_all

    TalkTopic.create!(talk: talk1, topic: topic_rails)
    TalkTopic.create!(talk: talk2, topic: topic_rails)
    TalkTopic.create!(talk: talk1, topic: topic_ruby)

    expected = "Discover all the talks given by Speaker With Topics on subjects related to Rails and Ruby."
    assert_equal expected, user.meta_description
  end

  test "meta_description limits to top 3 topics by frequency" do
    user = User.create!(name: "Prolific Speaker", github_handle: "prolific-speaker")

    talk1 = talks(:one)
    talk2 = talks(:two)

    UserTalk.create!(user: user, talk: talk1)
    UserTalk.create!(user: user, talk: talk2)
    user.update_column(:talks_count, 2)

    topic1 = Topic.create!(name: "Topic A", slug: "topic-a", status: "approved")
    topic2 = Topic.create!(name: "Topic B", slug: "topic-b", status: "approved")
    topic3 = Topic.create!(name: "Topic C", slug: "topic-c", status: "approved")
    topic4 = Topic.create!(name: "Topic D", slug: "topic-d", status: "approved")

    talk1.talk_topics.destroy_all
    talk2.talk_topics.destroy_all

    TalkTopic.create!(talk: talk1, topic: topic1)
    TalkTopic.create!(talk: talk2, topic: topic1)
    TalkTopic.create!(talk: talk1, topic: topic2)
    TalkTopic.create!(talk: talk2, topic: topic2)
    TalkTopic.create!(talk: talk1, topic: topic3)
    TalkTopic.create!(talk: talk2, topic: topic3)
    TalkTopic.create!(talk: talk1, topic: topic4)

    expected = "Discover all the talks given by Prolific Speaker on subjects related to Topic A, Topic B, and Topic C."
    assert_equal expected, user.meta_description
  end

  test "searchable scope returns users with searchable setting enabled" do
    searchable_user = User.create!(name: "Searchable User", github_handle: "searchable-user")
    non_searchable_user = User.create!(name: "Non Searchable User", github_handle: "non-searchable-user")
    non_searchable_user.update!(searchable: false)

    assert_includes User.searchable, searchable_user
    assert_not_includes User.searchable, non_searchable_user
  end

  test "indexable scope includes speakers regardless of searchable setting" do
    speaker = User.create!(name: "Speaker User", github_handle: "speaker-indexable", talks_count: 5)
    speaker.update!(searchable: false)

    assert_includes User.indexable, speaker
  end

  test "indexable scope includes non-speakers with searchable enabled" do
    user = User.create!(name: "Regular User", github_handle: "regular-indexable", talks_count: 0)

    assert_includes User.indexable, user
  end

  test "indexable scope excludes non-speakers with searchable disabled" do
    user = User.create!(name: "Hidden User", github_handle: "hidden-indexable", talks_count: 0)
    user.update!(searchable: false)

    assert_not_includes User.indexable, user
  end

  test "indexable scope excludes users marked for deletion" do
    user = User.create!(name: "Deleted User", github_handle: "deleted-indexable", marked_for_deletion: true)

    assert_not_includes User.indexable, user
  end

  test "indexable scope excludes non-canonical users" do
    canonical = User.create!(name: "Canonical", github_handle: "canonical-indexable")
    non_canonical = User.create!(name: "Non Canonical", github_handle: "non-canonical-indexable", canonical_id: canonical.id)

    assert_includes User.indexable, canonical
    assert_not_includes User.indexable, non_canonical
  end

  test "indexable? returns true for speakers regardless of searchable setting" do
    speaker = User.create!(name: "Speaker", github_handle: "speaker-method", talks_count: 5)
    speaker.update!(searchable: false)

    assert speaker.indexable?
  end

  test "indexable? returns true for non-speakers with searchable enabled" do
    user = User.create!(name: "Regular", github_handle: "regular-method", talks_count: 0)

    assert user.indexable?
  end

  test "indexable? returns false for non-speakers with searchable disabled" do
    user = User.create!(name: "Hidden", github_handle: "hidden-method", talks_count: 0)
    user.update!(searchable: false)

    assert_not user.indexable?
  end

  test "indexable? returns false for users marked for deletion" do
    user = User.create!(name: "Deleted", github_handle: "deleted-method", marked_for_deletion: true)

    assert_not user.indexable?
  end

  test "indexable? returns false for non-canonical users" do
    canonical = User.create!(name: "Canonical", github_handle: "canonical-method")
    non_canonical = User.create!(name: "Non Canonical", github_handle: "non-canonical-method", canonical_id: canonical.id)

    assert_not non_canonical.indexable?
  end

  test "creates alias when verified user changes name" do
    user = User.create!(name: "Original Name", github_handle: "alias-test-user")
    user.connected_accounts.create!(provider: "github", uid: "12345")

    user.update!(name: "New Name")

    assert_equal 1, user.aliases.count
    alias_record = user.aliases.first
    assert_equal "Original Name", alias_record.name
    assert_equal "original-name", alias_record.slug
  end

  test "does not create alias when user without connected account changes name" do
    user = User.create!(name: "Original Name", github_handle: "no-account-alias-test")

    user.update!(name: "New Name")

    assert_equal 0, user.aliases.count
  end

  test "does not create duplicate alias when name changes back" do
    user = User.create!(name: "Original Name", github_handle: "duplicate-alias-test")
    user.connected_accounts.create!(provider: "github", uid: "67890")

    user.update!(name: "New Name")
    user.update!(name: "Another Name")
    user.update!(name: "Original Name")
    user.update!(name: "Original Name")

    assert_equal 3, user.aliases.count
    assert user.aliases.exists?(name: "Original Name")
    assert user.aliases.exists?(name: "New Name")
    assert user.aliases.exists?(name: "Another Name")

    user.update!(name: "New Name")
    assert_equal 3, user.aliases.count
  end

  test "does not create alias when name is blank" do
    user = User.create!(name: "Has Name", github_handle: "blank-name-alias-test")
    user.connected_accounts.create!(provider: "github", uid: "11111")

    user.update_columns(name: "")
    user.reload
    user.update!(name: "New Name")

    assert_not user.aliases.exists?(name: "")
  end

  test "find_by_name_or_alias finds user by previous name after rename" do
    user = User.create!(name: "Speaker Original", github_handle: "speaker-rename-test")
    user.connected_accounts.create!(provider: "github", uid: "22222")

    user.update!(name: "Speaker New Name")

    found_user = User.find_by_name_or_alias("Speaker Original")
    assert_equal user.id, found_user.id
  end

  test "belongs to city record" do
    user = User.create!(name: "Amsterdam User", github_handle: "amsterdam-user", city: "Amsterdam", country_code: "NL", state_code: "")
    assert_equal "Amsterdam", user.city_record.name
  end
end
