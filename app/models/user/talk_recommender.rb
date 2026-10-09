class User::TalkRecommender < ActiveRecord::AssociatedObject
  def talks(limit: 4)
    return Talk.none if user.watched_talks.watched.empty?

    ids = candidate_ids(limit: limit).sample(limit, random: Random.new(daily_seed))

    Talk.where(id: ids).includes(:speakers, event: :series).in_order_of(:id, ids).to_a
  end

  private

  def candidate_ids(limit:)
    Rails.cache.fetch(["talk_recommendations", user.id, limit, watched_talks_version], expires_at: Date.current.end_of_day) do
      (collaborative_filtering_recommendations(limit: limit) + content_based_recommendations(limit: limit)).uniq.map(&:id)
    end
  end

  def watched_talks_version
    watched = user.watched_talks.watched

    "#{watched.maximum(:updated_at).to_i}-#{watched.count}"
  end

  def daily_seed
    user.id + Date.current.strftime("%Y%m%d").to_i
  end

  def watched_talk_ids
    user.watched_talks.watched.select(:talk_id)
  end

  def own_talk_ids
    user.user_talks.select(:talk_id)
  end

  def collaborative_filtering_recommendations(limit:)
    similar_user_ids = WatchedTalk.watched
      .where(talk_id: watched_talk_ids)
      .where.not(user_id: user.id)
      .group(:user_id)
      .having("COUNT(*) >= ?", 2)
      .order(Arel.sql("COUNT(*) DESC"))
      .limit(50)
      .pluck(:user_id)

    Talk.joins(:watched_talks)
      .where(watched_talks: {user_id: similar_user_ids})
      .where.not(id: watched_talk_ids)
      .where.not(id: own_talk_ids)
      .where(video_provider: Talk::WATCHABLE_PROVIDERS)
      .where.not(kind: Talk::NON_RECOMMENDABLE_KINDS)
      .group(:id)
      .order(Arel.sql("COUNT(watched_talks.id) DESC"))
      .limit(limit)
  end

  def content_based_recommendations(limit:)
    watched_topic_ids = user.watched_talks.watched
      .joins(talk: :approved_topics)
      .distinct
      .pluck("topics.id")

    Talk.joins(:approved_topics)
      .where(topics: {id: watched_topic_ids})
      .where.not(id: watched_talk_ids)
      .where.not(id: own_talk_ids)
      .where(video_provider: Talk::WATCHABLE_PROVIDERS)
      .where.not(kind: Talk::NON_RECOMMENDABLE_KINDS)
      .order("created_at DESC")
      .limit(limit)
  end
end
