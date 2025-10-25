class User::WatchedTalkSeeder < ActiveRecord::AssociatedObject
  def seed_development_data
    return unless Rails.env.development?

    watchable_talks = Talk.youtube.order(date: :desc).limit(100)

    return if watchable_talks.empty?

    existing_users = User.joins(:watched_talks).limit(10)

    seed_overlapping_patterns(watchable_talks, existing_users)
  end

  private

  def seed_overlapping_patterns(watchable_talks, existing_users)
    core_topics = Topic.approved.pluck(:name)

    core_shared_talks = watchable_talks.select do |talk|
      talk.approved_topics.any? { |topic| core_topics.include?(topic.name) }
    end.sample(3)

    sample_users = existing_users.sample(2)
    shared_talks = []

    sample_users.each do |existing_user|
      user_talks = existing_user.watched_talks.joins(:talk)
        .where(talk: watchable_talks)
        .includes(:talk)
        .sample(rand(1..2))
      shared_talks += user_talks.map(&:talk)
    end

    similar_topic_ids = (core_shared_talks + shared_talks).flat_map do |talk|
      talk.approved_topics.pluck(:id)
    end.uniq

    similar_talks = watchable_talks.joins(:approved_topics)
      .where(topics: {id: similar_topic_ids})
      .sample(4)

    used_talks = core_shared_talks + shared_talks + similar_talks
    random_talks = (watchable_talks - used_talks).sample(rand(2..4))

    all_talks = (core_shared_talks + shared_talks + similar_talks + random_talks)
      .uniq
      .sample(rand(10..15))

    all_talks.each do |talk|
      WatchedTalk.find_or_create_by(user: user, talk: talk) do |watched_talk|
        watched_talk.progress_seconds = rand(0..talk.duration_in_seconds || 1000)
        watched_talk.created_at = rand(6.months.ago..Time.current)
      end
    end
  end
end
