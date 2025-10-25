class User::TalkRecommender < ActiveRecord::AssociatedObject
  def talks(limit: 4)
    return Talk.none if user.watched_talks.empty?

    (collaborative_filtering_recommendations(limit: limit) + content_based_recommendations(limit: limit))
      .uniq
      .sample(limit)
  end

  private

  def collaborative_filtering_recommendations(limit:)
    similar_user_ids = WatchedTalk
      .where(talk_id: user.watched_talks.select(:talk_id))
      .where.not(user_id: user.id)
      .group(:user_id)
      .having("COUNT(*) >= ?", 2)
      .order(Arel.sql("COUNT(*) DESC"))
      .limit(50)
      .pluck(:user_id)

    Talk.joins(:watched_talks)
      .where(watched_talks: {user_id: similar_user_ids})
      .where.not(id: user.watched_talks.select(:talk_id))
      .where(video_provider: Talk::WATCHABLE_PROVIDERS)
      .group(:id)
      .order(Arel.sql("COUNT(watched_talks.id) DESC"))
      .limit(limit)
  end

  def content_based_recommendations(limit:)
    watched_topic_ids = user.watched_talks
      .joins(talk: :approved_topics)
      .distinct
      .pluck("topics.id")

    Talk.joins(:approved_topics)
      .where(topics: {id: watched_topic_ids})
      .where.not(id: user.watched_talks.select(:talk_id))
      .where(video_provider: Talk::WATCHABLE_PROVIDERS)
      .order("created_at DESC")
      .limit(limit)
  end
end
