# Shortlists approved, canonical topics worth scoring for a talk, so the judge
# rates a few dozen topics instead of the whole list. Candidates come from
# topic or alias names mentioned in the talk, topics already assigned to it, and
# topics common across its speakers' other talks.
#
class Talk::TopicCandidates
  MAX_CANDIDATES = 40
  SPEAKER_TOPICS_LIMIT = 10

  def self.for(talk)
    new(talk).candidates
  end

  def initialize(talk)
    @talk = talk
  end

  def candidates
    (assigned + mentioned + speaker_topics).uniq.first(MAX_CANDIDATES)
  end

  private

  attr_reader :talk

  def assigned
    talk.topics.includes(:canonical).map(&:primary_topic).select(&:approved?)
  end

  def mentioned
    text = [talk.title, talk.description, talk.summary, talk.transcript&.to_text].compact.join(" ").downcase

    pool.filter_map { |topic, names|
      count = names.sum { |name| text.scan(name_pattern(name)).size }
      [topic, count] if count.positive?
    }.sort_by { |_topic, count| -count }.map(&:first)
  end

  def speaker_topics
    speaker_talk_ids = UserTalk.where(user_id: talk.user_talks.select(:user_id)).where.not(talk_id: talk.id).select(:talk_id)

    Topic.approved.canonical
      .joins(:talk_topics).where(talk_topics: {talk_id: speaker_talk_ids})
      .group(:id).order(Arel.sql("COUNT(*) DESC"))
      .limit(SPEAKER_TOPICS_LIMIT)
      .to_a
  end

  def pool
    @pool ||= Topic.approved.canonical.includes(:aliases).to_h do |topic|
      [topic, [topic.name, *topic.aliases.map(&:name)].uniq]
    end
  end

  def name_pattern(name)
    /(?<![[:alnum:]])#{Regexp.escape(name.downcase)}(?![[:alnum:]])/
  end
end
