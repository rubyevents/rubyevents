module Insights
  module Classifiers
    EXCLUDED_SPEAKERS = ["TODO", "TBD", "TBA", "Speaker TBD", "Speaker TBA", "tbd", "tba", "todo"].freeze

    REGIONS = {
      "North America" => %w[US CA MX],
      "Europe" => %w[GB DE FR ES IT NL PL AT CH BE SE DK NO FI IE PT CZ HU RO BG HR SI SK],
      "Asia Pacific" => %w[JP AU NZ SG MY ID TH PH VN KR TW HK CN IN],
      "South America" => %w[BR AR CL CO PE EC UY],
      "Africa & Middle East" => %w[ZA NG KE EG IL AE]
    }.freeze

    TITLE_PATTERNS = {
      "Question Asker" => /^(why|how|what|when|where|who|can|should|could|would|is|are|do|does|did)\b/i,
      "Builder" => /^(building|creating|crafting|making|developing|designing|implementing)/i,
      "Journey Narrator" => /(from .+ to|journey|road to|path to|evolution of|story of)/i,
      "Provocateur" => /^(stop|don't|never|forget|rethinking|beyond|against|why you should(n't)?)/i,
      "Introducer" => /^(intro|introduction|getting started|beginner|101|basics|fundamentals)/i,
      "Deep Diver" => /(deep dive|under the hood|internals|behind the scenes|how .+ works)/i,
      "Future Gazer" => /(future|next|tomorrow|2\d{3}|what's coming|emerging)/i,
      "Problem Solver" => /(solving|debugging|fixing|handling|managing|dealing with)/i
    }.freeze

    SEASONS = {
      "Winter" => [12, 1, 2],
      "Spring" => [3, 4, 5],
      "Summer" => [6, 7, 8],
      "Fall" => [9, 10, 11]
    }.freeze

    class << self
      def country_to_region
        @country_to_region ||= REGIONS.each_with_object({}) do |(region, countries), hash|
          countries.each { |c| hash[c] = region }
        end
      end
    end

    # Title naming pattern classification
    module TitleLinguist
      def self.classify(titles)
        return {label: "Unknown", description: "Not enough data"} if titles.size < 2

        pattern_counts = Hash.new(0)
        titles.each do |title|
          TITLE_PATTERNS.each do |pattern_name, regex|
            pattern_counts[pattern_name] += 1 if title.match?(regex)
          end
        end

        primary = pattern_counts.max_by { |_, count| count }
        if primary && primary[1] > 0
          strength = (primary[1].to_f / titles.size * 100).round
          {
            label: primary[0],
            description: "#{strength}% of talks match this pattern",
            icon: pattern_icon(primary[0]),
            strength: strength
          }
        else
          {label: "Neutral", description: "No dominant pattern", icon: "📝"}
        end
      end

      def self.pattern_icon(pattern)
        case pattern
        when "Question Asker" then "❓"
        when "Builder" then "🔨"
        when "Journey Narrator" then "🛤️"
        when "Provocateur" then "🔥"
        when "Introducer" then "👋"
        when "Deep Diver" then "🏊"
        when "Future Gazer" then "🔮"
        when "Problem Solver" then "🔧"
        else "📝"
        end
      end
    end

    # Geographic circuit classification
    module CircuitTraveler
      def self.classify(country_codes)
        return {label: "Unknown", description: "No location data", icon: "❓"} if country_codes.empty?

        region_counts = Hash.new(0)
        country_codes.each do |code|
          region = Classifiers.country_to_region[code]
          region_counts[region] += 1 if region
        end

        return {label: "Unknown", description: "No region data", icon: "❓"} if region_counts.empty?

        primary_region = region_counts.max_by { |_, v| v }[0]
        country_count = country_codes.uniq.size
        is_global = region_counts.size >= 3

        circuit = if is_global
          "Global Nomad"
        elsif region_counts.size == 2
          region_counts.keys.sort.join(" ↔ ")
        else
          "#{primary_region} Local"
        end

        {
          label: circuit,
          description: "#{country_count} countries across #{region_counts.size} region(s)",
          icon: if is_global
                  "🌍"
                else
                  ((region_counts.size == 2) ? "✈️" : "🏠")
                end,
          primary_region: primary_region,
          country_count: country_count,
          is_global: is_global
        }
      end
    end

    # Speaker generation based on debut year
    module Generation
      def self.classify(first_year)
        return {label: "Unknown", description: "No dated talks", icon: "❓"} unless first_year

        generation = case first_year
        when 2005..2010 then "OG (2005-2010)"
        when 2011..2014 then "Early Rails (2011-2014)"
        when 2015..2018 then "Modern Era (2015-2018)"
        when 2019..2021 then "Pre-Pandemic (2019-2021)"
        when 2022..2030 then "New Wave (2022+)"
        else "Unknown"
        end

        icon = case first_year
        when 2005..2010 then "🏛️"
        when 2011..2014 then "⭐"
        when 2015..2018 then "📈"
        when 2019..2021 then "🦠"
        when 2022..2030 then "🌟"
        else "❓"
        end

        {
          label: generation,
          description: "Debuted in #{first_year}",
          icon: icon,
          debut_year: first_year
        }
      end
    end

    # Talk duration classification
    module DurationDNA
      def self.classify(durations_in_seconds)
        durations = durations_in_seconds.compact.select(&:positive?)
        return {label: "Unknown", description: "No duration data", icon: "❓"} if durations.size < 2

        minutes = durations.map { |d| d / 60.0 }
        avg = (minutes.sum / minutes.size).round(1)
        std_dev = Math.sqrt(minutes.map { |d| (d - avg)**2 }.sum / minutes.size).round(1)

        duration_type = if avg < 10
          "Lightning Specialist"
        elsif avg < 25
          "Short & Sweet"
        elsif avg < 40
          "Standard Format"
        elsif avg < 55
          "Deep Diver"
        else
          "Keynote Length"
        end

        consistency = if std_dev < 5
          "Highly Consistent"
        elsif std_dev < 15
          "Moderate Variety"
        else
          "Wild Card"
        end

        icon = case duration_type
        when "Lightning Specialist" then "⚡"
        when "Short & Sweet" then "🎯"
        when "Standard Format" then "📊"
        when "Deep Diver" then "🏊"
        when "Keynote Length" then "🎤"
        else "⏱️"
        end

        {
          label: duration_type,
          description: "Avg #{avg.round} min (#{consistency})",
          icon: icon,
          avg_duration: avg,
          std_dev: std_dev,
          consistency: consistency
        }
      end
    end

    # Solo vs collaborative style
    module CollaborationStyle
      def self.classify(speaker_counts)
        return {label: "Unknown", description: "No talk data", icon: "❓"} if speaker_counts.empty?

        solo = speaker_counts.count { |c| c == 1 }
        duo = speaker_counts.count { |c| c == 2 }
        group = speaker_counts.count { |c| c >= 3 }
        total = speaker_counts.size

        solo_ratio = (solo.to_f / total * 100).round

        style = if solo_ratio >= 80
          "Solo Artist"
        elsif solo_ratio >= 50
          "Mostly Solo"
        elsif (duo + group).to_f / total >= 0.8
          "Team Player"
        elsif duo > group
          "Dynamic Duo"
        else
          "Ensemble Cast"
        end

        icon = case style
        when "Solo Artist" then "🎤"
        when "Mostly Solo" then "🎸"
        when "Team Player" then "👥"
        when "Dynamic Duo" then "👯"
        when "Ensemble Cast" then "🎭"
        else "🎵"
        end

        {
          label: style,
          description: "#{solo_ratio}% solo presentations",
          icon: icon,
          solo_ratio: solo_ratio,
          unique_collaborators: speaker_counts.count { |c| c > 1 }
        }
      end
    end

    # Seasonal speaking pattern
    module SeasonalPattern
      def self.classify(months)
        return {label: "Unknown", description: "No date data", icon: "❓"} if months.size < 3

        season_counts = {}
        SEASONS.each do |season, season_months|
          count = months.count { |m| season_months.include?(m) }
          season_counts[season] = count
        end

        total = months.size
        dominant = season_counts.max_by { |_, v| v }
        concentration = (dominant[1].to_f / total * 100).round

        pattern = if concentration >= 60
          "#{dominant[0]} Specialist"
        elsif concentration >= 40
          "#{dominant[0]} Leaning"
        else
          "Year-Round Speaker"
        end

        icon = case dominant[0]
        when "Winter" then "❄️"
        when "Spring" then "🌸"
        when "Summer" then "☀️"
        when "Fall" then "🍂"
        else "📅"
        end

        {
          label: pattern,
          description: "#{concentration}% in #{dominant[0].downcase}",
          icon: icon,
          dominant_season: dominant[0],
          concentration: concentration
        }
      end
    end

    # Conference loyalty classification
    module ConferenceLoyalty
      def self.classify(series_appearances)
        return {label: "Unknown", description: "No series data", icon: "❓"} if series_appearances.empty?

        unique_series = series_appearances.uniq.size
        total_talks = series_appearances.size
        series_counts = series_appearances.tally
        max_at_one = series_counts.values.max

        loyalty_score = (max_at_one.to_f / total_talks * 100).round
        avg_per_series = (total_talks.to_f / unique_series).round(1)

        loyalty_type = if unique_series == 1
          "Exclusive"
        elsif loyalty_score >= 50
          "Loyal Regular"
        elsif unique_series >= 10
          "Conference Hopper"
        elsif avg_per_series >= 2
          "Multi-Loyalist"
        else
          "Explorer"
        end

        icon = case loyalty_type
        when "Exclusive" then "💍"
        when "Loyal Regular" then "💎"
        when "Conference Hopper" then "🦘"
        when "Multi-Loyalist" then "🔄"
        when "Explorer" then "🧭"
        else "🎪"
        end

        {
          label: loyalty_type,
          description: "#{unique_series} series, #{loyalty_score}% at favorite",
          icon: icon,
          unique_series: unique_series,
          loyalty_score: loyalty_score
        }
      end
    end

    # Talk recycling pattern
    module TalkRecycler
      def self.classify(titles)
        return {label: "Unknown", description: "Not enough talks", icon: "❓"} if titles.size < 3

        # Normalize titles
        normalized = titles.map { |t| t.to_s.downcase.gsub(/[^a-z0-9\s]/, "").gsub(/\s+/, " ").strip }

        similar_pairs = 0
        normalized.combination(2).each do |t1, t2|
          words1 = t1.split.to_set
          words2 = t2.split.to_set
          next if words1.size < 3 || words2.size < 3

          overlap = (words1 & words2).size
          union = (words1 | words2).size
          similarity = overlap.to_f / union

          similar_pairs += 1 if similarity > 0.5
        end

        total_pairs = titles.size * (titles.size - 1) / 2
        recycling_ratio = (total_pairs > 0) ? (similar_pairs.to_f / total_pairs * 100).round : 0

        style = if recycling_ratio >= 30
          "Tour Speaker"
        elsif recycling_ratio >= 10
          "Signature Talk"
        elsif recycling_ratio > 0
          "Occasional Repeat"
        else
          "Always Fresh"
        end

        icon = case style
        when "Tour Speaker" then "🎪"
        when "Signature Talk" then "🏆"
        when "Occasional Repeat" then "🔁"
        when "Always Fresh" then "✨"
        else "📝"
        end

        {
          label: style,
          description: "#{recycling_ratio}% similar talks",
          icon: icon,
          recycling_ratio: recycling_ratio
        }
      end
    end

    module TrendTiming
      def self.classify(early_count, late_count)
        total = early_count + late_count
        return {label: "Unknown", description: "Not enough topic data", icon: "❓"} if total < 3

        early_ratio = (early_count.to_f / total * 100).round

        timing_style = if early_ratio >= 70
          "Trend Setter"
        elsif early_ratio >= 40
          "Early Majority"
        elsif early_ratio >= 20
          "Late Majority"
        else
          "Classics Lover"
        end

        icon = case timing_style
        when "Trend Setter" then "🚀"
        when "Early Majority" then "📈"
        when "Late Majority" then "📊"
        when "Classics Lover" then "📚"
        else "⏰"
        end

        {
          label: timing_style,
          description: "#{early_ratio}% early adopter",
          icon: icon,
          early_ratio: early_ratio
        }
      end
    end

    module TitleEvolution
      def self.classify(titles_with_years)
        return {label: "Unknown", description: "Not enough talks", icon: "❓"} if titles_with_years.size < 4

        sorted = titles_with_years.sort_by { |t| t[:year] }
        first_half = sorted.first(sorted.size / 2)
        second_half = sorted.last(sorted.size / 2)

        avg_first = first_half.sum { |t| t[:word_count] }.to_f / first_half.size
        avg_second = second_half.sum { |t| t[:word_count] }.to_f / second_half.size
        avg_overall = (sorted.sum { |t| t[:word_count] }.to_f / sorted.size).round(1)
        word_count_change = (avg_second - avg_first).round(1)

        evolution = if word_count_change >= 2
          "Getting Verbose"
        elsif word_count_change <= -2
          "Getting Concise"
        elsif avg_overall <= 4
          "Always Punchy"
        elsif avg_overall >= 8
          "Always Descriptive"
        else
          "Stable Middle"
        end

        icon = case evolution
        when "Getting Verbose" then "📖"
        when "Getting Concise" then "✂️"
        when "Always Punchy" then "💥"
        when "Always Descriptive" then "📜"
        when "Stable Middle" then "⚖️"
        else "📝"
        end

        {
          label: evolution,
          description: "#{"+" if word_count_change >= 0}#{word_count_change} words over career",
          icon: icon,
          avg_word_count: avg_overall,
          word_count_change: word_count_change
        }
      end
    end

    module TopicEvolution
      def self.classify(topics_by_era)
        active_eras = topics_by_era.count { |_, topics| topics.any? }
        return {label: "Unknown", description: "Not active long enough", icon: "❓"} if active_eras < 2

        early = Set.new(topics_by_era["early"] || [])
        middle = Set.new(topics_by_era["middle"] || [])
        recent = Set.new(topics_by_era["recent"] || [])

        consistent = early & middle & recent

        evolution_type = if consistent.size >= 2
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

        icon = case evolution_type
        when "Consistent Expert" then "🎯"
        when "Topic Shifter" then "🔀"
        when "Expanding Horizons" then "🌅"
        when "Focused Specialist" then "🔬"
        when "Steady Evolution" then "📈"
        else "🔄"
        end

        trajectory = [
          (topics_by_era["early"] || []).first(2),
          (topics_by_era["middle"] || []).first(2),
          (topics_by_era["recent"] || []).first(2)
        ].flatten.compact.uniq.first(5)

        {
          label: evolution_type,
          description: "#{trajectory.size} topics across #{active_eras} eras",
          icon: icon,
          trajectory: trajectory
        }
      end
    end

    module MentorshipRole
      def self.classify(mentored_count, was_mentored, co_presentations)
        role = if mentored_count >= 3
          "Super Mentor"
        elsif mentored_count >= 1
          "Mentor"
        elsif was_mentored
          "Mentee Graduate"
        elsif co_presentations >= 3
          "Collaborator"
        else
          "Independent"
        end

        icon = case role
        when "Super Mentor" then "🏆"
        when "Mentor" then "🎓"
        when "Mentee Graduate" then "🌱"
        when "Collaborator" then "🤝"
        when "Independent" then "🎤"
        else "👤"
        end

        {
          label: role,
          description: (mentored_count > 0) ? "Mentored #{mentored_count} speaker(s)" : "#{co_presentations} co-presentations",
          icon: icon,
          mentored_count: mentored_count
        }
      end
    end

    module EventKindPreference
      def self.classify(event_kinds)
        return {label: "Unknown", description: "No event data", icon: "❓"} if event_kinds.empty?

        kind_counts = event_kinds.tally
        total = event_kinds.size

        conference_pct = ((kind_counts["conference"] || 0).to_f / total * 100).round
        meetup_pct = ((kind_counts["meetup"] || 0).to_f / total * 100).round
        workshop_pct = ((kind_counts["workshop"] || 0).to_f / total * 100).round

        preference = if conference_pct >= 70
          "Conference Regular"
        elsif meetup_pct >= 50
          "Community Builder"
        elsif workshop_pct >= 30
          "Workshop Wizard"
        elsif kind_counts.size >= 4
          "Event Omnivore"
        elsif conference_pct >= 40 && meetup_pct >= 30
          "Balanced Speaker"
        else
          "Mixed Circuit"
        end

        icon = case preference
        when "Conference Regular" then "🎪"
        when "Community Builder" then "🏘️"
        when "Workshop Wizard" then "🛠️"
        when "Event Omnivore" then "🦎"
        when "Balanced Speaker" then "⚖️"
        else "🎭"
        end

        {
          label: preference,
          description: "#{conference_pct}% conferences, #{meetup_pct}% meetups",
          icon: icon,
          conference_pct: conference_pct,
          meetup_pct: meetup_pct
        }
      end
    end

    module TalkFormatSpecialist
      def self.classify(talk_kinds)
        return {label: "Unknown", description: "No talk data", icon: "❓"} if talk_kinds.empty?

        kind_counts = talk_kinds.tally
        total = talk_kinds.size

        keynote_pct = ((kind_counts["keynote"] || 0).to_f / total * 100).round
        lightning_pct = ((kind_counts["lightning_talk"] || 0).to_f / total * 100).round
        panel_pct = ((kind_counts["panel"] || 0).to_f / total * 100).round
        workshop_pct = ((kind_counts["workshop"] || 0).to_f / total * 100).round
        regular_pct = ((kind_counts["talk"] || 0).to_f / total * 100).round

        specialty = if keynote_pct >= 30
          "Keynote Material"
        elsif lightning_pct >= 40
          "Speed Demon"
        elsif panel_pct >= 25
          "Discussion Leader"
        elsif workshop_pct >= 25
          "Hands-On Teacher"
        elsif regular_pct >= 80
          "Classic Presenter"
        else
          "Format Flexible"
        end

        icon = case specialty
        when "Keynote Material" then "⭐"
        when "Speed Demon" then "⚡"
        when "Discussion Leader" then "💬"
        when "Hands-On Teacher" then "👨‍🏫"
        when "Classic Presenter" then "🎯"
        else "🎨"
        end

        {
          label: specialty,
          description: "#{keynote_pct}% keynotes, #{lightning_pct}% lightning",
          icon: icon,
          keynote_pct: keynote_pct,
          lightning_pct: lightning_pct
        }
      end
    end

    module TopicBreadth
      def self.classify(talk_count, topic_count)
        return {label: "Unknown", description: "No topic data", icon: "❓"} if talk_count == 0 || topic_count == 0

        ratio = topic_count.to_f / talk_count

        breadth = if ratio >= 2.0
          "Renaissance Speaker"
        elsif ratio >= 1.2
          "Diverse Explorer"
        elsif ratio >= 0.7
          "Balanced Expert"
        elsif ratio >= 0.4
          "Focused Specialist"
        else
          "Deep Expert"
        end

        icon = case breadth
        when "Renaissance Speaker" then "🎭"
        when "Diverse Explorer" then "🧭"
        when "Balanced Expert" then "⚖️"
        when "Focused Specialist" then "🔬"
        when "Deep Expert" then "🎯"
        else "📚"
        end

        {
          label: breadth,
          description: "#{topic_count} topics across #{talk_count} talks",
          icon: icon,
          ratio: ratio.round(2)
        }
      end
    end

    module NetworkSize
      def self.classify(unique_collaborators, total_collabs)
        return {label: "Unknown", description: "No collaboration data", icon: "❓"} if total_collabs == 0

        network = if unique_collaborators >= 10
          "Super Connector"
        elsif unique_collaborators >= 5
          "Well Connected"
        elsif unique_collaborators >= 2
          "Selective Partner"
        elsif unique_collaborators == 1
          "Faithful Duo"
        else
          "Solo Flyer"
        end

        icon = case network
        when "Super Connector" then "🕸️"
        when "Well Connected" then "🤝"
        when "Selective Partner" then "👯"
        when "Faithful Duo" then "💑"
        when "Solo Flyer" then "🦅"
        else "👤"
        end

        {
          label: network,
          description: "#{unique_collaborators} unique co-speakers",
          icon: icon,
          unique_collaborators: unique_collaborators
        }
      end
    end

    module SlideSharing
      def self.classify(talks_with_slides, total_talks)
        return {label: "Unknown", description: "No talk data", icon: "❓"} if total_talks == 0

        share_pct = (talks_with_slides.to_f / total_talks * 100).round

        sharing = if share_pct >= 80
          "Open Book"
        elsif share_pct >= 50
          "Generous Sharer"
        elsif share_pct >= 20
          "Selective Sharer"
        elsif share_pct > 0
          "Occasional Sharer"
        else
          "Slides Keeper"
        end

        icon = case sharing
        when "Open Book" then "📖"
        when "Generous Sharer" then "🎁"
        when "Selective Sharer" then "🔐"
        when "Occasional Sharer" then "📎"
        when "Slides Keeper" then "🔒"
        else "📊"
        end

        {
          label: sharing,
          description: "#{share_pct}% of talks have slides shared",
          icon: icon,
          share_pct: share_pct
        }
      end
    end

    module LanguageDiversity
      LANGUAGE_NAMES = {
        "en" => "English",
        "ja" => "Japanese",
        "de" => "German",
        "fr" => "French",
        "es" => "Spanish",
        "pt" => "Portuguese",
        "zh" => "Chinese",
        "ko" => "Korean",
        "ru" => "Russian",
        "it" => "Italian",
        "pl" => "Polish",
        "nl" => "Dutch"
      }.freeze

      def self.classify(languages)
        return {label: "Unknown", description: "No language data", icon: "❓"} if languages.empty?

        unique_langs = languages.uniq
        primary = languages.tally.max_by { |_, v| v }[0]
        primary_name = LANGUAGE_NAMES[primary] || primary.upcase

        diversity = if unique_langs.size >= 4
          "Polyglot Speaker"
        elsif unique_langs.size == 3
          "Trilingual"
        elsif unique_langs.size == 2
          "Bilingual"
        elsif primary == "en"
          "English Speaker"
        else
          "#{primary_name} Speaker"
        end

        icon = if unique_langs.size >= 3
          "🌍"
        elsif unique_langs.size == 2
          "🗣️"
        elsif primary == "en"
          "🇬🇧"
        elsif primary == "ja"
          "🇯🇵"
        elsif primary == "de"
          "🇩🇪"
        elsif primary == "fr"
          "🇫🇷"
        else
          "💬"
        end

        {
          label: diversity,
          description: "#{unique_langs.size} language(s)",
          icon: icon,
          languages: unique_langs,
          primary: primary_name
        }
      end
    end

    module CareerCadence
      def self.classify(talks_by_year)
        return {label: "Unknown", description: "No date data", icon: "❓"} if talks_by_year.empty?

        years = talks_by_year.keys.sort
        counts = talks_by_year.values
        avg = (counts.sum.to_f / counts.size).round(1)
        max_year = talks_by_year.max_by { |_, v| v }
        current_year = Time.now.year

        first_years = years.first(3)
        last_years = years.last(3)
        first_avg = first_years.sum { |y| talks_by_year[y] || 0 }.to_f / [first_years.size, 1].max
        last_avg = last_years.sum { |y| talks_by_year[y] || 0 }.to_f / [last_years.size, 1].max

        trend = last_avg - first_avg

        cadence = if years.last >= current_year - 1 && trend >= 1
          "Rising Star"
        elsif years.last >= current_year - 1 && avg >= 3
          "Prolific Active"
        elsif years.last >= current_year - 1 && avg >= 1
          "Steady Active"
        elsif years.last < current_year - 2 && avg >= 2
          "Distinguished Alumni"
        elsif max_year[0] < current_year - 3 && trend <= -1
          "Peak Behind"
        elsif years.size == 1
          "One-Timer"
        else
          "Occasional Speaker"
        end

        icon = case cadence
        when "Rising Star" then "📈"
        when "Prolific Active" then "🔥"
        when "Steady Active" then "💪"
        when "Distinguished Alumni" then "🏆"
        when "Peak Behind" then "📉"
        when "One-Timer" then "1️⃣"
        else "📊"
        end

        {
          label: cadence,
          description: "~#{avg} talks/year, peak in #{max_year[0]}",
          icon: icon,
          avg_per_year: avg,
          peak_year: max_year[0],
          trend: trend.round(1)
        }
      end
    end

    module ContinentCoverage
      COUNTRY_TO_CONTINENT = {
        "US" => "North America", "CA" => "North America", "MX" => "North America",
        "GB" => "Europe", "DE" => "Europe", "FR" => "Europe", "ES" => "Europe", "IT" => "Europe",
        "NL" => "Europe", "PL" => "Europe", "AT" => "Europe", "CH" => "Europe", "BE" => "Europe",
        "SE" => "Europe", "DK" => "Europe", "NO" => "Europe", "FI" => "Europe", "IE" => "Europe",
        "PT" => "Europe", "CZ" => "Europe", "HU" => "Europe", "RO" => "Europe", "BG" => "Europe",
        "HR" => "Europe", "SI" => "Europe", "SK" => "Europe", "GR" => "Europe", "UA" => "Europe",
        "BY" => "Europe", "RS" => "Europe", "LT" => "Europe", "LV" => "Europe", "EE" => "Europe",
        "JP" => "Asia", "CN" => "Asia", "KR" => "Asia", "TW" => "Asia", "HK" => "Asia",
        "SG" => "Asia", "MY" => "Asia", "ID" => "Asia", "TH" => "Asia", "PH" => "Asia",
        "VN" => "Asia", "IN" => "Asia", "IL" => "Asia", "AE" => "Asia", "TR" => "Asia",
        "AU" => "Oceania", "NZ" => "Oceania",
        "BR" => "South America", "AR" => "South America", "CL" => "South America",
        "CO" => "South America", "PE" => "South America", "EC" => "South America", "UY" => "South America",
        "ZA" => "Africa", "NG" => "Africa", "KE" => "Africa", "EG" => "Africa", "MA" => "Africa"
      }.freeze

      def self.classify(country_codes)
        return {label: "Unknown", description: "No location data", icon: "❓"} if country_codes.empty?

        continents = country_codes.filter_map { |c| COUNTRY_TO_CONTINENT[c] }.uniq

        coverage = case continents.size
        when 6..7 then "World Traveler"
        when 4..5 then "Globe Trotter"
        when 3 then "Multi-Continental"
        when 2 then "Two-Continent"
        when 1 then "#{continents.first} Based"
        else "Local"
        end

        icon = case continents.size
        when 6..7 then "🌎"
        when 4..5 then "✈️"
        when 3 then "🗺️"
        when 2 then "🛫"
        else "🏠"
        end

        {
          label: coverage,
          description: "#{continents.size} continent(s): #{continents.join(", ")}",
          icon: icon,
          continents: continents,
          continent_count: continents.size
        }
      end
    end

    module HallwayTrack
      def self.classify(attendance_data)
        return {label: "Unknown", description: "No attendance data", icon: "❓"} if attendance_data.empty?

        total_watched = 0
        total_possible = 0

        attendance_data.each do |event_data|
          total_watched += event_data[:watched_in_person]
          total_possible += event_data[:max_possible]
        end

        return {label: "Unknown", description: "No talks available", icon: "❓"} if total_possible == 0

        ratio = (total_watched.to_f / total_possible * 100).round

        style = if ratio >= 75
          "Session Superfan"
        elsif ratio >= 50
          "Balanced Attendee"
        elsif ratio >= 25
          "Hallway Hero"
        elsif ratio > 0
          "Social Butterfly"
        else
          "Hallway Legend"
        end

        description = if ratio >= 75
          "Never misses a talk! #{total_watched}/#{total_possible} sessions attended"
        elsif ratio >= 50
          "Good balance of sessions and networking"
        elsif ratio >= 25
          "The hallway track is where the magic happens"
        elsif ratio > 0
          "Came for the vibes, stayed for the people"
        else
          "Who needs talks when you have coffee and conversations?"
        end

        icon = case style
        when "Session Superfan" then "🎯"
        when "Balanced Attendee" then "⚖️"
        when "Hallway Hero" then "☕"
        when "Social Butterfly" then "🦋"
        when "Hallway Legend" then "🗣️"
        else "👥"
        end

        {
          label: style,
          description: description,
          icon: icon,
          attendance_ratio: ratio,
          total_watched: total_watched,
          total_possible: total_possible,
          events_count: attendance_data.size
        }
      end

      def self.max_possible_talks(event)
        schedule = event.schedule

        if schedule.days.any?
          schedule.days.sum do |day|
            grid = day.fetch("grid", [])
            grid.count do |slot|
              items = slot.fetch("items", [])
              items.empty? || items.none? { |i| i.to_s.match?(/break|lunch|door|registration|opening|closing|sponsor/i) }
            end
          end
        else
          event.talks_count
        end
      end
    end

    module ViewPopularity
      def self.classify(total_views, talk_count)
        return {label: "Unknown", description: "No view data", icon: "❓"} if talk_count == 0

        avg_views = (total_views.to_f / talk_count).round

        popularity = if avg_views >= 50_000
          "Viral Speaker"
        elsif avg_views >= 20_000
          "Popular Voice"
        elsif avg_views >= 10_000
          "Growing Audience"
        elsif avg_views >= 5_000
          "Solid Following"
        elsif avg_views >= 1_000
          "Building Audience"
        else
          "Hidden Gem"
        end

        icon = case popularity
        when "Viral Speaker" then "🚀"
        when "Popular Voice" then "📢"
        when "Growing Audience" then "📈"
        when "Solid Following" then "👥"
        when "Building Audience" then "🌱"
        when "Hidden Gem" then "💎"
        else "👁️"
        end

        formatted_views = if total_views >= 1_000_000
          "#{(total_views / 1_000_000.0).round(1)}M"
        elsif total_views >= 1_000
          "#{(total_views / 1_000.0).round(1)}K"
        else
          total_views.to_s
        end

        {
          label: popularity,
          description: "#{formatted_views} total views (~#{avg_views.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}/talk)",
          icon: icon,
          total_views: total_views,
          avg_views: avg_views
        }
      end
    end

    module EventPioneer
      def self.classify(pioneered_count, total_series)
        return {label: "Unknown", description: "No series data", icon: "❓"} if total_series == 0

        pioneer_ratio = (pioneered_count.to_f / total_series * 100).round

        label = if pioneered_count >= 5
          "Serial Pioneer"
        elsif pioneered_count >= 2
          "Pioneer"
        elsif pioneered_count == 1
          "First Edition Speaker"
        else
          "Established Circuit"
        end

        icon = case label
        when "Serial Pioneer" then "🚀"
        when "Pioneer" then "🏴"
        when "First Edition Speaker" then "🥇"
        when "Established Circuit" then "🎪"
        else "📅"
        end

        {
          label: label,
          description: "#{pioneered_count} first edition(s) of #{total_series} series",
          icon: icon,
          pioneer_count: pioneered_count,
          pioneer_ratio: pioneer_ratio
        }
      end
    end
  end
end
