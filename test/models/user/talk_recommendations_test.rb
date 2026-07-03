require "test_helper"

class User::TalkRecommendationsTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @other_user = users(:two)
    @talk1 = talks(:one)
    @talk2 = talks(:two)
    @talk3 = talks(:three)

    @user.watched_talks.delete_all
    @other_user.watched_talks.delete_all
  end

  test "returns empty recommendations for user with no watched talks" do
    recommendations = @user.talk_recommender.talks

    assert_empty recommendations
  end

  test "collaborative filtering finds similar users" do
    @user.watched_talks.create!(talk: @talk1, watched: true)
    @user.watched_talks.create!(talk: @talk2, watched: true)

    @other_user.watched_talks.create!(talk: @talk1, watched: true)
    @other_user.watched_talks.create!(talk: @talk2, watched: true)
    @other_user.watched_talks.create!(talk: @talk3, watched: true)

    recommendations = @user.talk_recommender.talks

    assert_includes recommendations.map(&:id), @talk3.id, "Should recommend talks watched by similar users"
  end

  test "content-based recommendations use topics and speakers" do
    topic = topics(:activerecord)
    @talk1.topics << topic unless @talk1.topics.include?(topic)
    @talk2.topics << topic unless @talk2.topics.include?(topic)

    @user.watched_talks.create!(talk: @talk1, watched: true)

    recommendations = @user.talk_recommender.talks

    assert_not_empty recommendations, "Should provide content-based recommendations"
  end

  test "filters out already watched talks" do
    @user.watched_talks.create!(talk: @talk1, watched: true)
    @user.watched_talks.create!(talk: @talk2, watched: true)

    recommendations = @user.talk_recommender.talks

    watched_ids = @user.watched_talks.watched.pluck(:talk_id)
    recommended_ids = recommendations.map(&:id)

    assert_empty (watched_ids & recommended_ids), "Should not recommend already watched talks"
  end

  test "respects limit parameter" do
    limit = 3
    recommendations = @user.talk_recommender.talks(limit: limit)

    assert recommendations.length <= limit, "Should respect the limit parameter"
  end

  test "only recommends watchable talks" do
    @user.watched_talks.create!(talk: @talk1, watched: true)

    recommendations = @user.talk_recommender.talks

    watchable_providers = Talk::WATCHABLE_PROVIDERS
    recommendations.each do |talk|
      assert_includes watchable_providers, talk.video_provider, "Should only recommend watchable talks"
    end

    assert_not_nil recommendations, "Should return recommendations array"
  end
end
