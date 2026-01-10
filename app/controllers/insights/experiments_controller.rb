class Insights::ExperimentsController < ApplicationController
  skip_before_action :authenticate_user!

  EXCLUDED_SPEAKERS = ["TODO", "TBD", "TBA", "Speaker TBD", "Speaker TBA", "tbd", "tba", "todo"].freeze

  def title_linguists
    data = Rails.cache.fetch("insights:experiments:title_linguists", expires_in: 6.hours) do
      patterns = {
        "Question Askers" => /^(why|how|what|when|where|who|can|should|could|would|is|are|do|does|did)\b/i,
        "Builders" => /^(building|creating|crafting|making|developing|designing|implementing)/i,
        "Journey Narrators" => /(from .+ to|journey|road to|path to|evolution of|story of)/i,
        "Provocateurs" => /^(stop|don't|never|forget|rethinking|beyond|against|why you should(n't)?)/i,
        "Introducers" => /^(intro|introduction|getting started|beginner|101|basics|fundamentals)/i,
        "Deep Divers" => /(deep dive|under the hood|internals|behind the scenes|how .+ works)/i,
        "Future Gazers" => /(future|next|tomorrow|2\d{3}|what's coming|emerging)/i,
        "Problem Solvers" => /(solving|debugging|fixing|handling|managing|dealing with)/i
      }

      speaker_patterns = {}

      Talk.includes(:speakers).find_each do |talk|
        next if talk.title.blank?

        talk.speakers.each do |speaker|
          next if EXCLUDED_SPEAKERS.map(&:downcase).include?(speaker.name&.downcase)

          speaker_patterns[speaker.id] ||= {
            id: speaker.id,
            name: speaker.name,
            slug: speaker.slug,
            patterns: Hash.new(0),
            talk_count: 0
          }

          patterns.each do |pattern_name, regex|
            speaker_patterns[speaker.id][:patterns][pattern_name] += 1 if talk.title.match?(regex)
          end
          speaker_patterns[speaker.id][:talk_count] += 1
        end
      end

      speakers = speaker_patterns.values.select { |s| s[:talk_count] >= 3 }

      speakers.each do |s|
        primary = s[:patterns].max_by { |_, count| count }
        s[:primary_pattern] = primary ? primary[0] : "Neutral"
        s[:pattern_strength] = primary ? (primary[1].to_f / s[:talk_count] * 100).round : 0
      end

      pattern_groups = speakers.group_by { |s| s[:primary_pattern] }

      nodes = speakers.map do |s|
        {
          id: s[:id],
          name: s[:name],
          slug: s[:slug],
          pattern: s[:primary_pattern],
          strength: s[:pattern_strength],
          talk_count: s[:talk_count]
        }
      end

      links = []

      pattern_groups.each do |pattern, group|
        next if group.size < 2

        group.combination(2).each do |s1, s2|
          strength_diff = (s1[:pattern_strength] - s2[:pattern_strength]).abs
          next if strength_diff > 30

          links << {
            source: s1[:id],
            target: s2[:id],
            value: (100 - strength_diff) / 20.0
          }
        end
      end

      {
        nodes: nodes,
        links: links.sample(800),
        patterns: patterns.keys
      }
    end

    render json: data
  end

  def circuit_travelers
    data = Rails.cache.fetch("insights:experiments:circuit_travelers", expires_in: 6.hours) do
      regions = {
        "North America" => %w[US CA MX],
        "Europe" => %w[GB DE FR ES IT NL PL AT CH BE SE DK NO FI IE PT CZ HU RO BG HR SI SK],
        "Asia Pacific" => %w[JP AU NZ SG MY ID TH PH VN KR TW HK CN IN],
        "South America" => %w[BR AR CL CO PE EC UY],
        "Africa & Middle East" => %w[ZA NG KE EG IL AE]
      }

      country_to_region = {}
      regions.each { |region, countries| countries.each { |c| country_to_region[c] = region } }

      speaker_regions = {}

      Talk.includes(:speakers, :event).find_each do |talk|
        next unless talk.event&.country_code

        region = country_to_region[talk.event.country_code]
        next unless region

        talk.speakers.each do |speaker|
          next if EXCLUDED_SPEAKERS.map(&:downcase).include?(speaker.name&.downcase)

          speaker_regions[speaker.id] ||= {
            id: speaker.id,
            name: speaker.name,
            slug: speaker.slug,
            regions: Hash.new(0),
            countries: Set.new
          }

          speaker_regions[speaker.id][:regions][region] += 1
          speaker_regions[speaker.id][:countries] << talk.event.country_code
        end
      end

      speakers = speaker_regions.values.select { |s| s[:regions].values.sum >= 3 }

      speakers.each do |s|
        total = s[:regions].values.sum
        s[:region_percentages] = s[:regions].transform_values { |v| (v.to_f / total * 100).round }
        s[:primary_region] = s[:regions].max_by { |_, v| v }[0]
        s[:country_count] = s[:countries].size
        s[:is_global] = s[:regions].size >= 3

        s[:circuit] = if s[:is_global]
          "Global Nomad"
        elsif s[:regions].size == 2
          s[:regions].keys.sort.join(" ↔ ")
        else
          "#{s[:primary_region]} Local"
        end
      end

      nodes = speakers.map do |s|
        {
          id: s[:id],
          name: s[:name],
          slug: s[:slug],
          circuit: s[:circuit],
          primary_region: s[:primary_region],
          country_count: s[:country_count],
          is_global: s[:is_global]
        }
      end

      links = []

      speakers.combination(2).each do |s1, s2|
        shared_regions = s1[:regions].keys & s2[:regions].keys
        next if shared_regions.empty?

        overlap = shared_regions.size.to_f / (s1[:regions].keys | s2[:regions].keys).size
        next if overlap < 0.5

        links << {
          source: s1[:id],
          target: s2[:id],
          value: overlap * 5
        }
      end

      {
        nodes: nodes,
        links: links.sort_by { |l| -l[:value] }.first(600),
        circuits: speakers.map { |s| s[:circuit] }.uniq.sort
      }
    end

    render json: data
  end

  def temporal_twins
    data = Rails.cache.fetch("insights:experiments:temporal_twins", expires_in: 6.hours) do
      speaker_timeline = {}

      Talk.includes(:speakers).where.not(date: nil).find_each do |talk|
        year = talk.date.year

        talk.speakers.each do |speaker|
          next if EXCLUDED_SPEAKERS.map(&:downcase).include?(speaker.name&.downcase)

          speaker_timeline[speaker.id] ||= {
            id: speaker.id,
            name: speaker.name,
            slug: speaker.slug,
            years: Hash.new(0),
            first_year: nil,
            last_year: nil
          }

          speaker_timeline[speaker.id][:years][year] += 1
          speaker_timeline[speaker.id][:first_year] ||= year
          speaker_timeline[speaker.id][:first_year] = [speaker_timeline[speaker.id][:first_year], year].min
          speaker_timeline[speaker.id][:last_year] = [speaker_timeline[speaker.id][:last_year] || year, year].max
        end
      end

      speakers = speaker_timeline.values.select { |s| s[:years].values.sum >= 3 }

      speakers.each do |s|
        s[:total_talks] = s[:years].values.sum
        s[:active_years] = s[:years].size
        s[:career_span] = s[:last_year] - s[:first_year] + 1
        s[:talks_per_year] = (s[:total_talks].to_f / s[:career_span]).round(1)
        s[:generation] = case s[:first_year]
        when 2005..2010 then "OG (2005-2010)"
        when 2011..2014 then "Early Rails (2011-2014)"
        when 2015..2018 then "Modern Era (2015-2018)"
        when 2019..2021 then "Pre-Pandemic (2019-2021)"
        when 2022..2030 then "New Wave (2022+)"
        else "Unknown"
        end
      end

      nodes = speakers.map do |s|
        {
          id: s[:id],
          name: s[:name],
          slug: s[:slug],
          debut_year: s[:first_year],
          generation: s[:generation],
          talks_per_year: s[:talks_per_year],
          total_talks: s[:total_talks],
          career_span: s[:career_span]
        }
      end

      links = []
      speakers.combination(2).each do |s1, s2|
        next unless s1[:generation] == s2[:generation]

        freq_diff = (s1[:talks_per_year] - s2[:talks_per_year]).abs
        next if freq_diff > 1.0

        links << {
          source: s1[:id],
          target: s2[:id],
          value: 5 - freq_diff * 2,
          generation: s1[:generation]
        }
      end

      {
        nodes: nodes,
        links: links.sort_by { |l| -l[:value] }.first(800),
        generations: speakers.map { |s| s[:generation] }.uniq.sort
      }
    end

    render json: data
  end

  def duration_dna
    data = Rails.cache.fetch("insights:experiments:duration_dna", expires_in: 6.hours) do
      speaker_durations = {}

      Talk.includes(:speakers).where.not(duration_in_seconds: [nil, 0]).find_each do |talk|
        minutes = talk.duration_in_seconds / 60.0

        talk.speakers.each do |speaker|
          next if EXCLUDED_SPEAKERS.map(&:downcase).include?(speaker.name&.downcase)

          speaker_durations[speaker.id] ||= {
            id: speaker.id,
            name: speaker.name,
            slug: speaker.slug,
            durations: []
          }

          speaker_durations[speaker.id][:durations] << minutes
        end
      end

      speakers = speaker_durations.values.select { |s| s[:durations].size >= 3 }

      speakers.each do |s|
        durations = s[:durations]
        s[:avg_duration] = (durations.sum / durations.size).round(1)
        s[:min_duration] = durations.min.round(1)
        s[:max_duration] = durations.max.round(1)
        s[:std_dev] = Math.sqrt(durations.map { |d| (d - s[:avg_duration])**2 }.sum / durations.size).round(1)
        s[:talk_count] = durations.size

        s[:duration_type] = if s[:avg_duration] < 10
          "Lightning Specialist"
        elsif s[:avg_duration] < 25
          "Short & Sweet"
        elsif s[:avg_duration] < 40
          "Standard Format"
        elsif s[:avg_duration] < 55
          "Deep Diver"
        else
          "Keynote Length"
        end

        s[:consistency] = if s[:std_dev] < 5
          "Highly Consistent"
        elsif s[:std_dev] < 15
          "Moderate Variety"
        else
          "Wild Card"
        end
      end

      nodes = speakers.map do |s|
        {
          id: s[:id],
          name: s[:name],
          slug: s[:slug],
          duration_type: s[:duration_type],
          consistency: s[:consistency],
          avg_duration: s[:avg_duration],
          std_dev: s[:std_dev],
          talk_count: s[:talk_count]
        }
      end

      links = []

      speakers.combination(2).each do |s1, s2|
        next unless s1[:duration_type] == s2[:duration_type]
        next unless s1[:consistency] == s2[:consistency]

        avg_diff = (s1[:avg_duration] - s2[:avg_duration]).abs
        next if avg_diff > 10

        links << {
          source: s1[:id],
          target: s2[:id],
          value: (10 - avg_diff) / 2
        }
      end

      {
        nodes: nodes,
        links: links.sort_by { |l| -l[:value] }.first(600),
        duration_types: speakers.map { |s| s[:duration_type] }.uniq,
        consistency_types: speakers.map { |s| s[:consistency] }.uniq
      }
    end

    render json: data
  end

  def event_pioneers
    data = Rails.cache.fetch("insights:experiments:event_pioneers", expires_in: 6.hours) do
      first_editions = Event.where.not(start_date: nil)
        .group(:event_series_id)
        .minimum(:start_date)

      pioneer_speakers = {}

      Talk.includes(:speakers, event: :series).find_each do |talk|
        next unless talk.event&.event_series_id
        next unless talk.event.start_date

        first_date = first_editions[talk.event.event_series_id]
        next unless first_date

        is_first_edition = talk.event.start_date.year == first_date.year

        talk.speakers.each do |speaker|
          next if EXCLUDED_SPEAKERS.map(&:downcase).include?(speaker.name&.downcase)

          pioneer_speakers[speaker.id] ||= {
            id: speaker.id,
            name: speaker.name,
            slug: speaker.slug,
            pioneered_events: [],
            total_events: Set.new
          }

          pioneer_speakers[speaker.id][:total_events] << talk.event.event_series_id
          if is_first_edition
            pioneer_speakers[speaker.id][:pioneered_events] << talk.event.series.name
          end
        end
      end

      speakers = pioneer_speakers.values.select { |s| s[:pioneered_events].size >= 2 }

      speakers.each do |s|
        s[:pioneer_count] = s[:pioneered_events].uniq.size
        s[:total_series] = s[:total_events].size
        s[:pioneer_ratio] = (s[:pioneer_count].to_f / s[:total_series] * 100).round
        s[:pioneered_events] = s[:pioneered_events].uniq
      end

      nodes = speakers.map do |s|
        {
          id: s[:id],
          name: s[:name],
          slug: s[:slug],
          pioneer_count: s[:pioneer_count],
          pioneered_events: s[:pioneered_events].first(5),
          pioneer_ratio: s[:pioneer_ratio]
        }
      end

      links = []
      speakers.combination(2).each do |s1, s2|
        shared = s1[:pioneered_events] & s2[:pioneered_events]
        next if shared.empty?

        links << {
          source: s1[:id],
          target: s2[:id],
          value: shared.size * 2,
          shared_events: shared.first(3)
        }
      end

      {
        nodes: nodes,
        links: links.sort_by { |l| -l[:value] }.first(500)
      }
    end

    render json: data
  end

  def topic_evolution
    data = Rails.cache.fetch("insights:experiments:topic_evolution", expires_in: 6.hours) do
      speaker_topic_timeline = {}

      Talk.includes(:speakers, :topics).where.not(date: nil).find_each do |talk|
        year = talk.date.year
        era = case year
        when 2005..2012 then "early"
        when 2013..2017 then "middle"
        when 2018..2030 then "recent"
        else next
        end

        talk.speakers.each do |speaker|
          next if EXCLUDED_SPEAKERS.map(&:downcase).include?(speaker.name&.downcase)

          speaker_topic_timeline[speaker.id] ||= {
            id: speaker.id,
            name: speaker.name,
            slug: speaker.slug,
            topics_by_era: {"early" => [], "middle" => [], "recent" => []}
          }

          talk.topics.select { |t| t.status == "approved" }.each do |topic|
            speaker_topic_timeline[speaker.id][:topics_by_era][era] << topic.name
          end
        end
      end

      speakers = speaker_topic_timeline.values.select do |s|
        s[:topics_by_era].values.count { |t| t.any? } >= 2
      end

      speakers.each do |s|
        s[:topics_by_era].transform_values! { |topics| topics.uniq }

        early = Set.new(s[:topics_by_era]["early"])
        middle = Set.new(s[:topics_by_era]["middle"])
        recent = Set.new(s[:topics_by_era]["recent"])

        consistent = early & middle & recent

        s[:evolution_type] = if consistent.size >= 2
          "Consistent Expert"
        elsif (recent - early - middle).size > (early | middle).size / 2
          "Topic Shifter"
        elsif recent.size > early.size + middle.size
          "Expanding Horizons"
        elsif early.size > recent.size
          "Focused Specialist"
        else
          "Steady Evolution"
        end

        s[:topic_trajectory] = [
          s[:topics_by_era]["early"].first(2),
          s[:topics_by_era]["middle"].first(2),
          s[:topics_by_era]["recent"].first(2)
        ].flatten.compact.uniq.first(5)
      end

      nodes = speakers.map do |s|
        {
          id: s[:id],
          name: s[:name],
          slug: s[:slug],
          evolution_type: s[:evolution_type],
          trajectory: s[:topic_trajectory]
        }
      end

      links = []
      speakers.combination(2).each do |s1, s2|
        next unless s1[:evolution_type] == s2[:evolution_type]

        t1 = s1[:topic_trajectory].to_set
        t2 = s2[:topic_trajectory].to_set
        overlap = (t1 & t2).size

        next if overlap < 1

        links << {
          source: s1[:id],
          target: s2[:id],
          value: overlap * 2
        }
      end

      {
        nodes: nodes,
        links: links.sort_by { |l| -l[:value] }.first(600),
        evolution_types: speakers.map { |s| s[:evolution_type] }.uniq
      }
    end

    render json: data
  end

  def solo_ensemble
    data = Rails.cache.fetch("insights:experiments:solo_ensemble", expires_in: 6.hours) do
      speaker_collab = {}

      Talk.includes(:speakers).find_each do |talk|
        speaker_count = talk.speakers.count { |s| !EXCLUDED_SPEAKERS.map(&:downcase).include?(s.name&.downcase) }

        talk.speakers.each do |speaker|
          next if EXCLUDED_SPEAKERS.map(&:downcase).include?(speaker.name&.downcase)

          speaker_collab[speaker.id] ||= {
            id: speaker.id,
            name: speaker.name,
            slug: speaker.slug,
            solo_talks: 0,
            duo_talks: 0,
            group_talks: 0,
            co_speakers: Set.new
          }

          case speaker_count
          when 1 then speaker_collab[speaker.id][:solo_talks] += 1
          when 2 then speaker_collab[speaker.id][:duo_talks] += 1
          else speaker_collab[speaker.id][:group_talks] += 1
          end

          talk.speakers.each do |co|
            next if co.id == speaker.id
            next if EXCLUDED_SPEAKERS.map(&:downcase).include?(co.name&.downcase)
            speaker_collab[speaker.id][:co_speakers] << co.id
          end
        end
      end

      speakers = speaker_collab.values.select { |s| s[:solo_talks] + s[:duo_talks] + s[:group_talks] >= 3 }

      speakers.each do |s|
        total = s[:solo_talks] + s[:duo_talks] + s[:group_talks]
        s[:solo_ratio] = (s[:solo_talks].to_f / total * 100).round
        s[:collab_ratio] = ((s[:duo_talks] + s[:group_talks]).to_f / total * 100).round
        s[:unique_collaborators] = s[:co_speakers].size

        s[:style] = if s[:solo_ratio] >= 80
          "Solo Artist"
        elsif s[:solo_ratio] >= 50
          "Mostly Solo"
        elsif s[:collab_ratio] >= 80
          "Team Player"
        elsif s[:duo_talks] > s[:group_talks]
          "Dynamic Duo"
        else
          "Ensemble Cast"
        end
      end

      nodes = speakers.map do |s|
        {
          id: s[:id],
          name: s[:name],
          slug: s[:slug],
          style: s[:style],
          solo_ratio: s[:solo_ratio],
          unique_collaborators: s[:unique_collaborators],
          total_talks: s[:solo_talks] + s[:duo_talks] + s[:group_talks]
        }
      end

      links = []

      speakers.each do |s1|
        s1[:co_speakers].each do |co_id|
          s2 = speaker_collab[co_id]
          next unless s2
          next unless speakers.include?(s2)
          next if s1[:id] >= s2[:id]

          links << {
            source: s1[:id],
            target: s2[:id],
            value: 3
          }
        end
      end

      style_groups = speakers.group_by { |s| s[:style] }

      style_groups.each do |style, group|
        next if group.size < 2

        group.combination(2).each do |s1, s2|
          next if s1[:co_speakers].include?(s2[:id])

          ratio_diff = (s1[:solo_ratio] - s2[:solo_ratio]).abs
          next if ratio_diff > 15

          links << {
            source: s1[:id],
            target: s2[:id],
            value: 1
          }
        end
      end

      {
        nodes: nodes,
        links: links.sort_by { |l| -l[:value] }.first(800),
        styles: speakers.map { |s| s[:style] }.uniq
      }
    end

    render json: data
  end

  def trend_timing
    data = Rails.cache.fetch("insights:experiments:trend_timing", expires_in: 6.hours) do
      topic_first_year = {}

      TalkTopic.joins(:talk, :topic)
        .where(topics: {status: "approved"})
        .where.not(talks: {date: nil})
        .group("topics.id")
        .pluck(Arel.sql("topics.id, topics.name, MIN(strftime('%Y', talks.date))"))
        .each { |id, name, year| topic_first_year[id] = {name: name, year: year.to_i} }

      speaker_timing = {}

      Talk.includes(:speakers, :topics).where.not(date: nil).find_each do |talk|
        year = talk.date.year

        talk.speakers.each do |speaker|
          next if EXCLUDED_SPEAKERS.map(&:downcase).include?(speaker.name&.downcase)

          speaker_timing[speaker.id] ||= {
            id: speaker.id,
            name: speaker.name,
            slug: speaker.slug,
            early_adopter_count: 0,
            late_adopter_count: 0,
            topics_talked: []
          }

          talk.topics.select { |t| t.status == "approved" }.each do |topic|
            first = topic_first_year[topic.id]
            next unless first

            years_after_introduction = year - first[:year]
            if years_after_introduction <= 1
              speaker_timing[speaker.id][:early_adopter_count] += 1
            elsif years_after_introduction >= 3
              speaker_timing[speaker.id][:late_adopter_count] += 1
            end
            speaker_timing[speaker.id][:topics_talked] << topic.name
          end
        end
      end

      speakers = speaker_timing.values.select { |s| s[:early_adopter_count] + s[:late_adopter_count] >= 3 }

      speakers.each do |s|
        total = s[:early_adopter_count] + s[:late_adopter_count]
        s[:early_ratio] = (s[:early_adopter_count].to_f / total * 100).round
        s[:timing_style] = if s[:early_ratio] >= 70
          "Trend Setter"
        elsif s[:early_ratio] >= 40
          "Early Majority"
        elsif s[:early_ratio] >= 20
          "Late Majority"
        else
          "Classics Lover"
        end
        s[:topics_talked] = s[:topics_talked].uniq.first(5)
      end

      nodes = speakers.map do |s|
        {
          id: s[:id],
          name: s[:name],
          slug: s[:slug],
          timing_style: s[:timing_style],
          early_ratio: s[:early_ratio],
          topics: s[:topics_talked]
        }
      end

      links = []
      speakers.combination(2).each do |s1, s2|
        next unless s1[:timing_style] == s2[:timing_style]
        ratio_diff = (s1[:early_ratio] - s2[:early_ratio]).abs
        next if ratio_diff > 20

        links << {source: s1[:id], target: s2[:id], value: (20 - ratio_diff) / 5.0}
      end

      {nodes: nodes, links: links.sort_by { |l| -l[:value] }.first(600)}
    end

    render json: data
  end

  def talk_recyclers
    data = Rails.cache.fetch("insights:experiments:talk_recyclers", expires_in: 6.hours) do
      speaker_talks = {}

      Talk.includes(:speakers, :event).find_each do |talk|
        next if talk.title.blank?

        talk.speakers.each do |speaker|
          next if EXCLUDED_SPEAKERS.map(&:downcase).include?(speaker.name&.downcase)

          speaker_talks[speaker.id] ||= {
            id: speaker.id,
            name: speaker.name,
            slug: speaker.slug,
            titles: [],
            events: Set.new
          }

          normalized = talk.title.downcase.gsub(/[^a-z0-9\s]/, "").gsub(/\s+/, " ").strip
          speaker_talks[speaker.id][:titles] << normalized
          speaker_talks[speaker.id][:events] << talk.event_id if talk.event_id
        end
      end

      speakers = speaker_talks.values.select { |s| s[:titles].size >= 3 }

      speakers.each do |s|
        titles = s[:titles]
        similar_pairs = 0

        titles.combination(2).each do |t1, t2|
          words1 = t1.split.to_set
          words2 = t2.split.to_set
          next if words1.size < 3 || words2.size < 3

          overlap = (words1 & words2).size
          union = (words1 | words2).size
          similarity = overlap.to_f / union

          similar_pairs += 1 if similarity > 0.5
        end

        s[:similar_talk_pairs] = similar_pairs
        s[:unique_events] = s[:events].size
        s[:recycling_ratio] = (titles.size > 1) ? (similar_pairs.to_f / (titles.size * (titles.size - 1) / 2) * 100).round : 0

        s[:style] = if s[:recycling_ratio] >= 30
          "Tour Speaker"
        elsif s[:recycling_ratio] >= 10
          "Signature Talk"
        elsif s[:recycling_ratio] > 0
          "Occasional Repeat"
        else
          "Always Fresh"
        end
      end

      nodes = speakers.select { |s| s[:similar_talk_pairs] > 0 || s[:titles].size >= 5 }.map do |s|
        {
          id: s[:id],
          name: s[:name],
          slug: s[:slug],
          style: s[:style],
          recycling_ratio: s[:recycling_ratio],
          talk_count: s[:titles].size,
          unique_events: s[:unique_events]
        }
      end

      links = []
      nodes_hash = nodes.index_by { |n| n[:id] }
      speakers.select { |s| nodes_hash[s[:id]] }.combination(2).each do |s1, s2|
        next unless s1[:style] == s2[:style]
        next if (s1[:recycling_ratio] - s2[:recycling_ratio]).abs > 15

        links << {source: s1[:id], target: s2[:id], value: 2}
      end

      {nodes: nodes, links: links.first(500)}
    end

    render json: data
  end

  def seasonal_speakers
    data = Rails.cache.fetch("insights:experiments:seasonal_speakers", expires_in: 6.hours) do
      speaker_months = {}

      Talk.includes(:speakers).where.not(date: nil).find_each do |talk|
        month = talk.date.month

        talk.speakers.each do |speaker|
          next if EXCLUDED_SPEAKERS.map(&:downcase).include?(speaker.name&.downcase)

          speaker_months[speaker.id] ||= {
            id: speaker.id,
            name: speaker.name,
            slug: speaker.slug,
            months: Hash.new(0)
          }

          speaker_months[speaker.id][:months][month] += 1
        end
      end

      speakers = speaker_months.values.select { |s| s[:months].values.sum >= 4 }

      season_names = {
        "Winter" => [12, 1, 2],
        "Spring" => [3, 4, 5],
        "Summer" => [6, 7, 8],
        "Fall" => [9, 10, 11]
      }

      speakers.each do |s|
        total = s[:months].values.sum

        s[:seasons] = {}

        season_names.each do |season, months|
          count = months.sum { |m| s[:months][m] }
          s[:seasons][season] = (count.to_f / total * 100).round
        end

        dominant = s[:seasons].max_by { |_, v| v }
        s[:dominant_season] = dominant[0]
        s[:season_concentration] = dominant[1]

        s[:pattern] = if s[:season_concentration] >= 60
          "#{s[:dominant_season]} Specialist"
        elsif s[:season_concentration] >= 40
          "#{s[:dominant_season]} Leaning"
        else
          "Year-Round Speaker"
        end
      end

      nodes = speakers.map do |s|
        {
          id: s[:id],
          name: s[:name],
          slug: s[:slug],
          pattern: s[:pattern],
          dominant_season: s[:dominant_season],
          concentration: s[:season_concentration],
          seasons: s[:seasons]
        }
      end

      links = []
      speakers.combination(2).each do |s1, s2|
        next unless s1[:dominant_season] == s2[:dominant_season]
        conc_diff = (s1[:season_concentration] - s2[:season_concentration]).abs
        next if conc_diff > 20

        links << {source: s1[:id], target: s2[:id], value: (20 - conc_diff) / 5.0}
      end

      {nodes: nodes, links: links.sort_by { |l| -l[:value] }.first(600)}
    end

    render json: data
  end

  def conference_loyalty
    data = Rails.cache.fetch("insights:experiments:conference_loyalty", expires_in: 6.hours) do
      speaker_series = {}

      Talk.includes(:speakers, :event).find_each do |talk|
        next unless talk.event&.event_series_id

        talk.speakers.each do |speaker|
          next if EXCLUDED_SPEAKERS.map(&:downcase).include?(speaker.name&.downcase)

          speaker_series[speaker.id] ||= {
            id: speaker.id,
            name: speaker.name,
            slug: speaker.slug,
            series_appearances: Hash.new(0),
            total_talks: 0
          }

          speaker_series[speaker.id][:series_appearances][talk.event.event_series_id] += 1
          speaker_series[speaker.id][:total_talks] += 1
        end
      end

      speakers = speaker_series.values.select { |s| s[:total_talks] >= 4 }

      speakers.each do |s|
        s[:unique_series] = s[:series_appearances].size
        s[:max_at_one_series] = s[:series_appearances].values.max
        s[:loyalty_score] = (s[:max_at_one_series].to_f / s[:total_talks] * 100).round
        s[:avg_per_series] = (s[:total_talks].to_f / s[:unique_series]).round(1)

        s[:loyalty_type] = if s[:unique_series] == 1
          "Exclusive"
        elsif s[:loyalty_score] >= 50
          "Loyal Regular"
        elsif s[:unique_series] >= 10
          "Conference Hopper"
        elsif s[:avg_per_series] >= 2
          "Multi-Loyalist"
        else
          "Explorer"
        end
      end

      nodes = speakers.map do |s|
        {
          id: s[:id],
          name: s[:name],
          slug: s[:slug],
          loyalty_type: s[:loyalty_type],
          unique_series: s[:unique_series],
          loyalty_score: s[:loyalty_score],
          total_talks: s[:total_talks]
        }
      end

      links = []
      speakers.combination(2).each do |s1, s2|
        next unless s1[:loyalty_type] == s2[:loyalty_type]

        shared = (s1[:series_appearances].keys & s2[:series_appearances].keys).size
        next if shared == 0 && s1[:loyalty_type] != "Conference Hopper"

        links << {source: s1[:id], target: s2[:id], value: 1 + shared}
      end

      {nodes: nodes, links: links.sort_by { |l| -l[:value] }.first(600)}
    end

    render json: data
  end

  def mentorship_network
    data = Rails.cache.fetch("insights:experiments:mentorship", expires_in: 6.hours) do
      speaker_first_talk = {}

      Talk.includes(:speakers).where.not(date: nil).order(:date).find_each do |talk|
        talk.speakers.each do |speaker|
          next if EXCLUDED_SPEAKERS.map(&:downcase).include?(speaker.name&.downcase)
          speaker_first_talk[speaker.id] ||= talk.date
        end
      end

      mentor_stats = {}

      Talk.includes(:speakers).where.not(date: nil).find_each do |talk|
        speakers = talk.speakers.reject { |s| EXCLUDED_SPEAKERS.map(&:downcase).include?(s.name&.downcase) }
        next if speakers.size < 2

        speakers.each do |speaker|
          mentor_stats[speaker.id] ||= {
            id: speaker.id,
            name: speaker.name,
            slug: speaker.slug,
            mentored: [],
            was_mentored_by: [],
            co_presentations: 0
          }

          mentor_stats[speaker.id][:co_presentations] += 1

          speakers.each do |co_speaker|
            next if co_speaker.id == speaker.id

            speaker_first = speaker_first_talk[speaker.id]
            co_first = speaker_first_talk[co_speaker.id]
            next unless speaker_first && co_first

            if talk.date == co_first && speaker_first < co_first
              mentor_stats[speaker.id][:mentored] << co_speaker.name
            elsif talk.date == speaker_first && co_first < speaker_first
              mentor_stats[speaker.id][:was_mentored_by] << co_speaker.name
            end
          end
        end
      end

      speakers = mentor_stats.values.select { |s| s[:mentored].any? || s[:co_presentations] >= 3 }

      speakers.each do |s|
        s[:mentored] = s[:mentored].uniq
        s[:was_mentored_by] = s[:was_mentored_by].uniq
        s[:mentored_count] = s[:mentored].size
        s[:mentor_score] = s[:mentored_count]

        s[:role] = if s[:mentored_count] >= 3
          "Super Mentor"
        elsif s[:mentored_count] >= 1
          "Mentor"
        elsif s[:was_mentored_by].any?
          "Mentee Graduate"
        else
          "Solo Collaborator"
        end
      end

      nodes = speakers.map do |s|
        {
          id: s[:id],
          name: s[:name],
          slug: s[:slug],
          role: s[:role],
          mentored_count: s[:mentored_count],
          mentored: s[:mentored].first(5),
          co_presentations: s[:co_presentations]
        }
      end

      links = []
      speakers.select { |s| s[:mentored].any? }.map { |s| s[:id] }
      speakers.flat_map { |s| s[:was_mentored_by] }.uniq

      speakers.combination(2).each do |s1, s2|
        if s1[:mentored].include?(s2[:name])
          links << {source: s1[:id], target: s2[:id], value: 5}
        elsif s2[:mentored].include?(s1[:name])
          links << {source: s2[:id], target: s1[:id], value: 5}
        elsif s1[:role] == s2[:role] && s1[:role] != "Solo Collaborator"
          links << {source: s1[:id], target: s2[:id], value: 1}
        end
      end

      {nodes: nodes, links: links.sort_by { |l| -l[:value] }.first(500)}
    end

    render json: data
  end

  def title_evolution
    data = Rails.cache.fetch("insights:experiments:title_evolution", expires_in: 6.hours) do
      speaker_titles = {}

      Talk.includes(:speakers).where.not(date: nil).order(:date).find_each do |talk|
        next if talk.title.blank?

        talk.speakers.each do |speaker|
          next if EXCLUDED_SPEAKERS.map(&:downcase).include?(speaker.name&.downcase)

          speaker_titles[speaker.id] ||= {
            id: speaker.id,
            name: speaker.name,
            slug: speaker.slug,
            titles_over_time: []
          }

          speaker_titles[speaker.id][:titles_over_time] << {
            year: talk.date.year,
            length: talk.title.length,
            word_count: talk.title.split.size
          }
        end
      end

      speakers = speaker_titles.values.select { |s| s[:titles_over_time].size >= 4 }

      speakers.each do |s|
        titles = s[:titles_over_time].sort_by { |t| t[:year] }

        first_half = titles.first(titles.size / 2)
        second_half = titles.last(titles.size / 2)

        avg_first = first_half.sum { |t| t[:word_count] }.to_f / first_half.size
        avg_second = second_half.sum { |t| t[:word_count] }.to_f / second_half.size

        s[:avg_word_count] = (titles.sum { |t| t[:word_count] }.to_f / titles.size).round(1)
        s[:word_count_change] = (avg_second - avg_first).round(1)

        s[:evolution] = if s[:word_count_change] >= 2
          "Getting Verbose"
        elsif s[:word_count_change] <= -2
          "Getting Concise"
        elsif s[:avg_word_count] <= 4
          "Always Punchy"
        elsif s[:avg_word_count] >= 8
          "Always Descriptive"
        else
          "Stable Middle"
        end

        s[:talk_count] = titles.size
      end

      nodes = speakers.map do |s|
        {
          id: s[:id],
          name: s[:name],
          slug: s[:slug],
          evolution: s[:evolution],
          avg_word_count: s[:avg_word_count],
          word_count_change: s[:word_count_change],
          talk_count: s[:talk_count]
        }
      end

      links = []
      speakers.combination(2).each do |s1, s2|
        next unless s1[:evolution] == s2[:evolution]
        avg_diff = (s1[:avg_word_count] - s2[:avg_word_count]).abs
        next if avg_diff > 2

        links << {source: s1[:id], target: s2[:id], value: 3 - avg_diff}
      end

      {nodes: nodes, links: links.sort_by { |l| -l[:value] }.first(500)}
    end

    render json: data
  end

  def event_buddies
    data = Rails.cache.fetch("insights:experiments:event_buddies:v2", expires_in: 1.hour) do
      user_events = {}

      EventParticipation.includes(:user, :event).find_each do |participation|
        next unless participation.user && participation.event

        user_events[participation.user_id] ||= {
          id: participation.user_id,
          name: participation.user.name,
          slug: participation.user.slug,
          events: Set.new,
          as_visitor: 0,
          as_speaker: 0
        }

        user_events[participation.user_id][:events] << participation.event_id
        if participation.attended_as_visitor?
          user_events[participation.user_id][:as_visitor] += 1
        else
          user_events[participation.user_id][:as_speaker] += 1
        end
      end

      users = user_events.values.select { |u| u[:events].size >= 2 }

      users.each do |u|
        total = u[:as_visitor] + u[:as_speaker]
        u[:event_count] = u[:events].size
        u[:visitor_ratio] = (u[:as_visitor].to_f / total * 100).round

        u[:attendance_type] = if u[:as_speaker] > 0 && u[:as_visitor] == 0
          "Speaker Only"
        elsif u[:as_visitor] > 0 && u[:as_speaker] == 0
          "Attendee Only"
        elsif u[:as_speaker] > u[:as_visitor]
          "Mostly Speaker"
        else
          "Mixed"
        end
      end

      nodes = users.map do |u|
        {
          id: u[:id],
          name: u[:name],
          slug: u[:slug],
          event_count: u[:event_count],
          attendance_type: u[:attendance_type],
          visitor_ratio: u[:visitor_ratio]
        }
      end

      links = []

      users.combination(2).each do |u1, u2|
        shared = (u1[:events] & u2[:events]).size
        next if shared < 2

        union = (u1[:events] | u2[:events]).size
        similarity = shared.to_f / union

        next if similarity < 0.2

        links << {
          source: u1[:id],
          target: u2[:id],
          value: (similarity * 10).round(1),
          shared_events: shared
        }
      end

      connected_ids = Set.new

      links.each do |link|
        connected_ids << link[:source]
        connected_ids << link[:target]
      end

      filtered_nodes = nodes.select { |n| connected_ids.include?(n[:id]) }

      {
        nodes: filtered_nodes,
        links: links.sort_by { |l| -l[:value] }.first(400)
      }
    end

    render json: data
  end

  def watch_party
    data = Rails.cache.fetch("insights:experiments:watch_party", expires_in: 1.hour) do
      user_talks = {}

      WatchedTalk.includes(:user, talk: [:topics, :event]).where(watched: true).find_each do |wt|
        next unless wt.user && wt.talk

        user_talks[wt.user_id] ||= {
          id: wt.user_id,
          name: wt.user.name,
          slug: wt.user.slug,
          talks: Set.new,
          topics: Hash.new(0),
          events: Set.new
        }

        user_talks[wt.user_id][:talks] << wt.talk_id
        user_talks[wt.user_id][:events] << wt.talk.event_id if wt.talk.event_id

        wt.talk.topics.select { |t| t.status == "approved" }.each do |topic|
          user_talks[wt.user_id][:topics][topic.name] += 1
        end
      end

      users = user_talks.values.select { |u| u[:talks].size >= 5 }

      users.each do |u|
        u[:talk_count] = u[:talks].size
        u[:event_count] = u[:events].size
        u[:top_topics] = u[:topics].sort_by { |_, v| -v }.first(5).map(&:first)

        u[:viewer_type] = if u[:event_count] >= 10
          "Event Explorer"
        elsif u[:topics].size >= 8
          "Topic Curious"
        elsif u[:topics].values.max.to_i >= 5
          "Topic Focused"
        else
          "Casual Viewer"
        end
      end

      nodes = users.map do |u|
        {
          id: u[:id],
          name: u[:name],
          slug: u[:slug],
          talk_count: u[:talk_count],
          viewer_type: u[:viewer_type],
          top_topics: u[:top_topics]
        }
      end

      links = []

      users.combination(2).each do |u1, u2|
        shared_talks = (u1[:talks] & u2[:talks]).size
        talk_union = (u1[:talks] | u2[:talks]).size

        t1 = u1[:topics].keys.to_set
        t2 = u2[:topics].keys.to_set
        shared_topics = (t1 & t2).size

        talk_sim = (talk_union > 0) ? shared_talks.to_f / talk_union : 0
        next if shared_talks == 0 && shared_topics < 3

        links << {
          source: u1[:id],
          target: u2[:id],
          value: (talk_sim * 5) + (shared_topics * 0.5),
          shared_talks: shared_talks,
          shared_topics: shared_topics
        }
      end

      {
        nodes: nodes,
        links: links.sort_by { |l| -l[:value] }.first(600)
      }
    end

    render json: data
  end

  def country_clusters
    data = Rails.cache.fetch("insights:experiments:country_clusters", expires_in: 6.hours) do
      speaker_countries = {}

      Talk.includes(:speakers, :event).find_each do |talk|
        next unless talk.event&.country_code

        talk.speakers.each do |speaker|
          next if EXCLUDED_SPEAKERS.map(&:downcase).include?(speaker.name&.downcase)

          speaker_countries[speaker.id] ||= {
            id: speaker.id,
            name: speaker.name,
            slug: speaker.slug,
            countries: Hash.new(0),
            talk_count: 0
          }

          speaker_countries[speaker.id][:countries][talk.event.country_code] += 1
          speaker_countries[speaker.id][:talk_count] += 1
        end
      end

      speakers = speaker_countries.values.select { |s| s[:talk_count] >= 3 }

      speakers.each do |s|
        s[:country_count] = s[:countries].size
        s[:primary_country] = s[:countries].max_by { |_, v| v }[0]
        s[:primary_count] = s[:countries].values.max
        s[:home_ratio] = (s[:primary_count].to_f / s[:talk_count] * 100).round

        s[:travel_style] = if s[:country_count] == 1
          "Local Champion"
        elsif s[:country_count] >= 5
          "World Traveler"
        elsif s[:home_ratio] >= 70
          "Home Base + Trips"
        else
          "Regional Speaker"
        end
      end

      nodes = speakers.map do |s|
        {
          id: s[:id],
          name: s[:name],
          slug: s[:slug],
          travel_style: s[:travel_style],
          primary_country: s[:primary_country],
          country_count: s[:country_count],
          talk_count: s[:talk_count]
        }
      end

      links = []

      speakers.combination(2).each do |s1, s2|
        shared = (s1[:countries].keys & s2[:countries].keys)
        next if shared.empty?

        links << {
          source: s1[:id],
          target: s2[:id],
          value: shared.size * 2,
          shared_countries: shared.first(3)
        }
      end

      {
        nodes: nodes,
        links: links.sort_by { |l| -l[:value] }.first(700)
      }
    end

    render json: data
  end

  def talk_affinities
    data = Rails.cache.fetch("insights:experiments:talk_affinities", expires_in: 6.hours) do
      speaker_characteristics = {}

      Talk.includes(:speakers).where.not(duration_in_seconds: [nil, 0]).find_each do |talk|
        minutes = talk.duration_in_seconds / 60.0

        talk.speakers.each do |speaker|
          next if EXCLUDED_SPEAKERS.map(&:downcase).include?(speaker.name&.downcase)

          speaker_characteristics[speaker.id] ||= {
            id: speaker.id,
            name: speaker.name,
            slug: speaker.slug,
            durations: [],
            title_lengths: [],
            has_subtitle: 0,
            question_titles: 0,
            talk_count: 0
          }

          speaker_characteristics[speaker.id][:durations] << minutes
          speaker_characteristics[speaker.id][:title_lengths] << (talk.title&.split&.size || 0)
          speaker_characteristics[speaker.id][:has_subtitle] += 1 if talk.title&.include?(":")
          speaker_characteristics[speaker.id][:question_titles] += 1 if talk.title&.match?(/\?$/)
          speaker_characteristics[speaker.id][:talk_count] += 1
        end
      end

      speakers = speaker_characteristics.values.select { |s| s[:talk_count] >= 3 }

      speakers.each do |s|
        s[:avg_duration] = (s[:durations].sum / s[:durations].size).round(1)
        s[:avg_title_words] = (s[:title_lengths].sum.to_f / s[:title_lengths].size).round(1)
        s[:subtitle_ratio] = (s[:has_subtitle].to_f / s[:talk_count] * 100).round
        s[:question_ratio] = (s[:question_titles].to_f / s[:talk_count] * 100).round

        duration_type = if s[:avg_duration] < 15
          "Quick"
        elsif s[:avg_duration] < 35
          "Standard"
        else
          "Extended"
        end

        title_type = if s[:avg_title_words] <= 4
          "Punchy"
        elsif s[:avg_title_words] <= 7
          "Balanced"
        else
          "Detailed"
        end

        s[:talk_style] = "#{duration_type} & #{title_type}"
      end

      nodes = speakers.map do |s|
        {
          id: s[:id],
          name: s[:name],
          slug: s[:slug],
          talk_style: s[:talk_style],
          avg_duration: s[:avg_duration],
          avg_title_words: s[:avg_title_words],
          talk_count: s[:talk_count]
        }
      end

      links = []

      speakers.combination(2).each do |s1, s2|
        next unless s1[:talk_style] == s2[:talk_style]

        duration_diff = (s1[:avg_duration] - s2[:avg_duration]).abs
        title_diff = (s1[:avg_title_words] - s2[:avg_title_words]).abs

        next if duration_diff > 10 || title_diff > 3

        similarity = 5 - (duration_diff / 5) - title_diff
        links << {
          source: s1[:id],
          target: s2[:id],
          value: [similarity, 1].max
        }
      end

      {
        nodes: nodes,
        links: links.sort_by { |l| -l[:value] }.first(600)
      }
    end

    render json: data
  end
end
