class Insights::SpeakersController < ApplicationController
  skip_before_action :authenticate_user!

  EXCLUDED_SPEAKERS = ["TODO", "TBD", "TBA", "Speaker TBD", "Speaker TBA", "tbd", "tba", "todo"].freeze

  def prolific
    data = Rails.cache.fetch("insights:speakers:prolific", expires_in: 1.hour) do
      User
        .speakers
        .where.not("LOWER(users.name) IN (?)", EXCLUDED_SPEAKERS.map(&:downcase))
        .left_joins(:talks)
        .group(:id)
        .order("COUNT(talks.id) DESC")
        .limit(50)
        .select("users.id, users.name, users.slug, COUNT(talks.id) as talk_count")
        .map do |speaker|
          {
            id: speaker.id,
            name: speaker.name,
            slug: speaker.slug,
            talk_count: speaker.talk_count
          }
        end
    end

    render json: data
  end

  def co_attendance
    data = Rails.cache.fetch("insights:speakers:co_attendance", expires_in: 6.hours) do
      excluded = EXCLUDED_SPEAKERS.map { |s| "'#{s.downcase}'" }.join(", ")

      co_speakers = ActiveRecord::Base.connection.execute(<<~SQL)
        SELECT
          u1.id as speaker1_id,
          u1.name as speaker1_name,
          u1.slug as speaker1_slug,
          u2.id as speaker2_id,
          u2.name as speaker2_name,
          u2.slug as speaker2_slug,
          COUNT(DISTINCT t1.event_id) as shared_events
        FROM user_talks ut1
        JOIN talks t1 ON ut1.talk_id = t1.id
        JOIN user_talks ut2 ON ut2.talk_id != ut1.talk_id
        JOIN talks t2 ON ut2.talk_id = t2.id AND t1.event_id = t2.event_id
        JOIN users u1 ON ut1.user_id = u1.id
        JOIN users u2 ON ut2.user_id = u2.id
        WHERE ut1.user_id < ut2.user_id
          AND ut1.discarded_at IS NULL
          AND ut2.discarded_at IS NULL
          AND LOWER(u1.name) NOT IN (#{excluded})
          AND LOWER(u2.name) NOT IN (#{excluded})
        GROUP BY u1.id, u2.id
        HAVING shared_events >= 2
        ORDER BY shared_events DESC
        LIMIT 500
      SQL

      speakers = {}
      links = []

      co_speakers.each do |row|
        speakers[row["speaker1_id"]] ||= {
          id: row["speaker1_id"],
          name: row["speaker1_name"],
          slug: row["speaker1_slug"]
        }
        speakers[row["speaker2_id"]] ||= {
          id: row["speaker2_id"],
          name: row["speaker2_name"],
          slug: row["speaker2_slug"]
        }
        links << {
          source: row["speaker1_id"],
          target: row["speaker2_id"],
          value: row["shared_events"]
        }
      end

      {
        nodes: speakers.values,
        links: links
      }
    end

    render json: data
  end

  def topics
    data = Rails.cache.fetch("insights:speakers:topics", expires_in: 6.hours) do
      excluded_list = EXCLUDED_SPEAKERS.map(&:downcase)

      speaker_topics = User
        .joins(talks: :talk_topics)
        .joins("JOIN topics t ON talk_topics.topic_id = t.id")
        .where("user_talks.discarded_at IS NULL")
        .where("t.status = ?", "approved")
        .where.not("LOWER(users.name) IN (?)", excluded_list)
        .group("users.id, t.id")
        .having("COUNT(DISTINCT talks.id) >= 2")
        .order(Arel.sql("COUNT(DISTINCT talks.id) DESC"))
        .limit(500)
        .pluck(Arel.sql("users.id, users.name, users.slug, t.id, t.name, t.slug, COUNT(DISTINCT talks.id)"))
        .map do |speaker_id, speaker_name, speaker_slug, topic_id, topic_name, topic_slug, talk_count|
          {
            speaker_id: speaker_id,
            speaker_name: speaker_name,
            speaker_slug: speaker_slug,
            topic_id: topic_id,
            topic_name: topic_name,
            topic_slug: topic_slug,
            talk_count: talk_count
          }
        end

      speakers = {}
      topics = {}
      links = []

      speaker_topics.each do |row|
        speakers[row[:speaker_id]] ||= {
          id: "speaker_#{row[:speaker_id]}",
          name: row[:speaker_name],
          slug: row[:speaker_slug],
          type: "speaker"
        }
        topics[row[:topic_id]] ||= {
          id: "topic_#{row[:topic_id]}",
          name: row[:topic_name],
          slug: row[:topic_slug],
          type: "topic"
        }
        links << {
          source: "speaker_#{row[:speaker_id]}",
          target: "topic_#{row[:topic_id]}",
          value: row[:talk_count]
        }
      end

      {
        nodes: speakers.values + topics.values,
        links: links
      }
    end

    render json: data
  end

  def clusters
    data = Rails.cache.fetch("insights:speakers:clusters", expires_in: 6.hours) do
      excluded_list = EXCLUDED_SPEAKERS.map(&:downcase)

      speaker_topics = User
        .joins(talks: :talk_topics)
        .joins("JOIN topics t ON talk_topics.topic_id = t.id")
        .where("user_talks.discarded_at IS NULL")
        .where("t.status = ?", "approved")
        .where.not("LOWER(users.name) IN (?)", excluded_list)
        .group("users.id, t.id")
        .having("COUNT(DISTINCT talks.id) >= 2")
        .pluck(Arel.sql("users.id, users.name, users.slug, t.id, t.name, COUNT(DISTINCT talks.id)"))

      speaker_data = {}

      speaker_topics.each do |speaker_id, speaker_name, speaker_slug, topic_id, topic_name, count|
        speaker_data[speaker_id] ||= {
          id: speaker_id,
          name: speaker_name,
          slug: speaker_slug,
          topics: {},
          total_talks: 0
        }
        speaker_data[speaker_id][:topics][topic_id] = {name: topic_name, count: count}
        speaker_data[speaker_id][:total_talks] += count
      end

      speakers = speaker_data.values.select { |s| s[:topics].size >= 2 }
      links = []

      speakers.combination(2).each do |s1, s2|
        topics1 = Set.new(s1[:topics].keys)
        topics2 = Set.new(s2[:topics].keys)

        intersection = (topics1 & topics2).size
        union = (topics1 | topics2).size

        next if intersection < 2

        similarity = intersection.to_f / union
        next if similarity < 0.2

        links << {
          source: s1[:id],
          target: s2[:id],
          value: (similarity * 10).round(1),
          shared_topics: intersection
        }
      end

      connected_ids = Set.new

      links.each do |link|
        connected_ids << link[:source]
        connected_ids << link[:target]
      end

      nodes = speakers
        .select { |s| connected_ids.include?(s[:id]) }
        .map do |s|
          primary_topic = s[:topics].max_by { |_, v| v[:count] }
          {
            id: s[:id],
            name: s[:name],
            slug: s[:slug],
            primary_topic: primary_topic&.last&.dig(:name),
            topic_count: s[:topics].size,
            total_talks: s[:total_talks]
          }
        end

      {nodes: nodes, links: links.first(300)}
    end

    render json: data
  end

  def topic_network
    data = Rails.cache.fetch("insights:speakers:topic_network", expires_in: 6.hours) do
      excluded_list = EXCLUDED_SPEAKERS.map(&:downcase)

      speaker_topics = User
        .joins(talks: :talk_topics)
        .joins("JOIN topics t ON talk_topics.topic_id = t.id")
        .where("user_talks.discarded_at IS NULL")
        .where("t.status = ?", "approved")
        .where.not("LOWER(users.name) IN (?)", excluded_list)
        .group("users.id, t.id")
        .pluck(Arel.sql("users.id, users.name, users.slug, t.id, t.name"))

      speaker_data = {}
      topic_speaker_count = Hash.new(0)
      topic_id_to_name = {}

      speaker_topics.each do |speaker_id, speaker_name, speaker_slug, topic_id, topic_name|
        speaker_data[speaker_id] ||= {
          id: speaker_id,
          name: speaker_name,
          slug: speaker_slug,
          topics: {}
        }
        speaker_data[speaker_id][:topics][topic_id] = topic_name
        topic_speaker_count[topic_id] += 1
        topic_id_to_name[topic_id] = topic_name
      end

      keep_topics = ["developer experience", "dx", "hotwire", "turbo", "stimulus", "rails engines", "view components"].map(&:downcase)

      total_speakers = speaker_data.size
      common_topic_ids = topic_speaker_count
        .select { |id, count| count > total_speakers * 0.15 && !keep_topics.include?(topic_id_to_name[id]&.downcase) }
        .keys
        .to_set

      excluded_topic_names = common_topic_ids.map { |id| topic_id_to_name[id] }.compact

      speaker_data.each_value do |s|
        s[:topics].reject! { |id, _| common_topic_ids.include?(id) }
      end

      speakers = speaker_data.values.select { |s| s[:topics].size >= 2 }
      links = []
      speaker_list = speakers.to_a

      speaker_list.each_with_index do |s1, i|
        (i + 1...speaker_list.size).each do |j|
          s2 = speaker_list[j]

          topic_ids1 = s1[:topics].keys.to_set
          topic_ids2 = s2[:topics].keys.to_set

          intersection = (topic_ids1 & topic_ids2).size
          next if intersection < 1

          union = (topic_ids1 | topic_ids2).size
          similarity = intersection.to_f / union

          next if similarity < 0.15

          links << {
            source: s1[:id],
            target: s2[:id],
            value: (similarity * 10).round(2),
            shared_topics: intersection
          }
        end
      end


      adjacency = Hash.new { |h, k| h[k] = Set.new }
      links.each do |link|
        adjacency[link[:source]] << link[:target]
        adjacency[link[:target]] << link[:source]
      end

      visited = Set.new
      clusters = []

      speaker_list.each do |speaker|
        next if visited.include?(speaker[:id])
        next unless adjacency.key?(speaker[:id])

        cluster = []
        queue = [speaker[:id]]

        while queue.any?
          current = queue.shift
          next if visited.include?(current)

          visited << current
          cluster << current

          adjacency[current].each do |neighbor|
            queue << neighbor unless visited.include?(neighbor)
          end
        end

        clusters << cluster if cluster.size >= 2
      end

      speaker_cluster = {}

      clusters.each_with_index do |cluster, idx|
        cluster.each { |speaker_id| speaker_cluster[speaker_id] = idx }
      end

      connected_ids = Set.new

      links.each do |link|
        connected_ids << link[:source]
        connected_ids << link[:target]
      end

      nodes = speakers
        .select { |s| connected_ids.include?(s[:id]) }
        .map do |s|
          {
            id: s[:id],
            name: s[:name],
            slug: s[:slug],
            topics: s[:topics].values.first(5),
            topic_count: s[:topics].size,
            cluster: speaker_cluster[s[:id]] || 0
          }
        end

      {
        nodes: nodes,
        links: links.sort_by { |l| -l[:value] }.first(1000),
        cluster_count: clusters.size,
        excluded_topics: excluded_topic_names
      }
    end

    render json: data
  end
end
