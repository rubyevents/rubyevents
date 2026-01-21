class Talk::SimilarRecommender < ActiveRecord::AssociatedObject
  def talks(limit: 12)
    return Talk.none if topic_ids.empty?

    similar_talk_ids = Talk.joins(:approved_topics)
      .where(topics: {id: topic_ids})
      .where.not(id: talk.id)
      .watchable
      .group(:id)
      .order(Arel.sql("COUNT(topics.id) DESC"), date: :desc)
      .limit(limit)
      .pluck(:id)

    Talk.where(id: similar_talk_ids)
      .includes(:speakers, :event)
      .in_order_of(:id, similar_talk_ids)
  end

  def topic_ids
    @topic_ids ||= talk.approved_topics.pluck(:id)
  end

  def topics
    talk.approved_topics
  end
end
