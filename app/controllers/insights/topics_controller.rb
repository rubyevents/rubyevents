class Insights::TopicsController < ApplicationController
  skip_before_action :authenticate_user!

  def relationships
    data = Rails.cache.fetch("insights:topics:relationships", expires_in: 6.hours) do
      co_occurrences = ActiveRecord::Base.connection.execute(<<~SQL)
        SELECT
          t1.topic_id as topic1_id,
          top1.name as topic1_name,
          top1.slug as topic1_slug,
          t2.topic_id as topic2_id,
          top2.name as topic2_name,
          top2.slug as topic2_slug,
          COUNT(*) as co_occurrence_count
        FROM talk_topics t1
        JOIN talk_topics t2 ON t1.talk_id = t2.talk_id AND t1.topic_id < t2.topic_id
        JOIN topics top1 ON t1.topic_id = top1.id
        JOIN topics top2 ON t2.topic_id = top2.id
        WHERE top1.status = 'approved' AND top2.status = 'approved'
        GROUP BY t1.topic_id, t2.topic_id
        HAVING co_occurrence_count >= 3
        ORDER BY co_occurrence_count DESC
        LIMIT 300
      SQL

      topic_counts = Topic.approved
        .joins(:talk_topics)
        .group(:id)
        .count("talk_topics.id")

      topics = {}
      links = []

      co_occurrences.each do |row|
        topics[row["topic1_id"]] ||= {
          id: row["topic1_id"],
          name: row["topic1_name"],
          slug: row["topic1_slug"],
          talk_count: topic_counts[row["topic1_id"]] || 0
        }
        topics[row["topic2_id"]] ||= {
          id: row["topic2_id"],
          name: row["topic2_name"],
          slug: row["topic2_slug"],
          talk_count: topic_counts[row["topic2_id"]] || 0
        }
        links << {
          source: row["topic1_id"],
          target: row["topic2_id"],
          value: row["co_occurrence_count"]
        }
      end

      {
        nodes: topics.values,
        links: links
      }
    end

    render json: data
  end

  def trends
    data = Rails.cache.fetch("insights:topics:trends", expires_in: 1.hour) do
      top_topics = Topic.approved
        .joins(:talk_topics)
        .group(:id)
        .order("COUNT(talk_topics.id) DESC")
        .limit(15)
        .pluck(:id)

      yearly_counts = TalkTopic
        .joins(:talk, :topic)
        .where(topic_id: top_topics)
        .where.not(talks: {date: nil})
        .group(Arel.sql("topics.name"), Arel.sql("strftime('%Y', talks.date)"))
        .count

      years = yearly_counts.keys.map(&:last).uniq.compact.sort
      topic_names = yearly_counts.keys.map(&:first).uniq

      years.map do |year|
        row = {year: year}

        topic_names.each do |topic|
          row[topic] = yearly_counts[[topic, year]] || 0
        end

        row
      end
    end

    render json: data
  end
end
