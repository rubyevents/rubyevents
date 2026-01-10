module Insights
  class SpeakerProfile
    attr_reader :speaker

    def initialize(speaker)
      @speaker = speaker
      @talks = speaker.talks.includes(:event, :topics, :speakers)
    end

    def compute
      has_in_person_data = speaker.watched_talks.exists?(watched_on: "in_person")

      return nil if @talks.empty? && !has_in_person_data

      {
        speaker_id: speaker.id,
        speaker_name: speaker.name,
        speaker_slug: speaker.slug,
        talk_count: @talks.count,
        categories: compute_categories,
        stats: compute_stats,
        top_topics: top_topics(5)
      }
    end

    def to_llm_prompt(format: :prose)
      profile = compute

      return nil unless profile

      case format
      when :json
        to_llm_json(profile)
      else
        to_llm_prose(profile)
      end
    end

    def generate_summary
      json_data = to_llm_prompt(format: :json)
      return nil unless json_data

      prompt = <<~PROMPT
        You are a friendly Ruby community chronicler writing speaker profile summaries for RubyEvents.org.

        Write a fun, engaging 2-3 paragraph profile summary based on the JSON data provided.
        Be creative and playful while staying accurate to the data.
        Weave the classification labels and stats into a narrative.
        Highlight what makes this speaker unique.
        Use a warm, celebratory tone.

        Do NOT use bullet points or lists - write in prose paragraphs.
        Do NOT include any markdown formatting.
        Do NOT start with the speaker's name as a header.
        Start directly with an engaging opening line about the speaker.

        Here is the speaker data:

        #{json_data}
      PROMPT

      response = RubyLLM.chat(model: "gpt-4.1-nano").ask(prompt)
      response.content
    end

    def cached_summary
      cache_key = "speaker_profile_summary/#{speaker.id}/#{speaker.updated_at.to_i}"

      Rails.cache.fetch(cache_key, expires_in: 1.week) do
        generate_summary
      end
    end

    def generate_talk_suggestions
      json_data = to_llm_prompt(format: :json)
      return nil unless json_data

      prompt = <<~PROMPT
        You are a conference talk coach helping Ruby community speakers discover their next great talk idea.

        Based on this speaker's unique expertise and experience, suggest 5 potential talk topics they could explore next.

        ## Speaker's Core Strengths (prioritize these):
        Focus on natural extensions of their existing work, deeper dives into their specialties, and unique perspectives only they can offer.

        ## For context, here's what's currently popular in the community:
        #{trending_topics_context}

        ## Some newer topics gaining traction:
        #{emerging_topics_context}

        Consider (in order of priority):
        1. Their unique expertise and what only THEY can speak about
        2. Natural progressions from their existing talks
        3. Deeper dives into topics they've touched on
        4. Their speaking style (#{compute_categories[:title_pattern][:label]})
        5. Optionally: how their expertise might intersect with ONE trending topic

        For each suggestion, provide:
        1. A catchy talk title (matching their title style)
        2. A one-sentence description
        3. Why this topic uniquely suits them

        Format as a simple numbered list. Be creative but realistic.
        Prioritize their strengths over trends. At most 1-2 suggestions should reference trends.
        Don't suggest topics they've already covered extensively.

        Speaker data:
        #{json_data}
      PROMPT

      response = RubyLLM.chat(model: "gpt-4.1-nano").ask(prompt)
      response.content
    end

    def trending_topics_context
      recent_topics = Topic.joins(:talks)
        .where(talks: {date: 2.years.ago..})
        .where(status: "approved")
        .group("topics.id", "topics.name")
        .order(Arel.sql("COUNT(*) DESC"))
        .limit(15)
        .pluck("topics.name", Arel.sql("COUNT(*)"))

      recent_topics.map { |name, count| "- #{name} (#{count} recent talks)" }.join("\n")
    end

    def emerging_topics_context
      new_topics = Topic.joins(:talks)
        .where(status: "approved")
        .group("topics.id", "topics.name")
        .having("MIN(talks.date) >= ?", 2.years.ago)
        .order(Arel.sql("COUNT(*) DESC"))
        .limit(10)
        .pluck("topics.name", Arel.sql("COUNT(*)"))

      if new_topics.any?
        new_topics.map { |name, count| "- #{name} (#{count} talks, new topic)" }.join("\n")
      else
        "- AI/ML integration with Ruby\n- Hotwire & Turbo patterns\n- Ruby 3.x features\n- Rails 7+ innovations"
      end
    end

    def upcoming_themes_context
      upcoming_topics = Topic.joins(talks: :event)
        .where(events: {start_date: 6.months.ago..6.months.from_now})
        .where(status: "approved")
        .group("topics.name")
        .order(Arel.sql("COUNT(*) DESC"))
        .limit(10)
        .pluck("topics.name")

      if upcoming_topics.any?
        upcoming_topics.map { |name| "- #{name}" }.join("\n")
      else
        "- Performance optimization\n- Developer experience\n- Testing strategies\n- Modern deployment"
      end
    end

    def cached_talk_suggestions
      cache_key = "speaker_talk_suggestions/#{speaker.id}/#{speaker.updated_at.to_i}"

      Rails.cache.fetch(cache_key, expires_in: 1.week) do
        generate_talk_suggestions
      end
    end

    private

    CATEGORY_LABELS = {
      title_pattern: "Talk Titles",
      circuit: "Conference Circuit",
      generation: "Speaker Generation",
      duration: "Talk Duration",
      collaboration: "Collaboration Style",
      seasonal: "Seasonal Pattern",
      loyalty: "Conference Loyalty",
      recycling: "Talk Originality",
      trend_timing: "Topic Timing",
      title_evolution: "Title Evolution",
      topic_evolution: "Topic Evolution",
      mentorship: "Mentorship Role",
      pioneer: "Event Pioneer",
      event_kind: "Event Preference",
      talk_format: "Talk Format",
      topic_breadth: "Topic Breadth",
      network_size: "Speaker Network",
      slide_sharing: "Slide Sharing",
      language: "Language",
      cadence: "Career Cadence",
      continents: "Geographic Reach",
      popularity: "Popularity",
      hallway_track: "Hallway Track"
    }.freeze

    def to_llm_json(profile)
      data = {
        task: "Write a fun, engaging 2-3 paragraph profile summary for this Ruby community member. Be creative and playful while staying accurate. Weave the data into a narrative that highlights what makes them unique.",
        speaker: {
          name: speaker.name,
          slug: speaker.slug,
          bio: speaker.bio.presence,
          github: speaker.github_handle.presence,
          twitter: speaker.twitter.presence,
          mastodon: speaker.mastodon.presence,
          bsky: speaker.bsky.presence,
          website: speaker.website.presence,
          location: speaker.location.presence
        },
        stats: profile[:stats],
        categories: profile[:categories].map do |key, cat|
          {
            category: CATEGORY_LABELS[key] || key.to_s.titleize,
            key: key,
            classification: cat[:label],
            description: cat[:description],
            icon: cat[:icon],
            raw_data: cat.except(:label, :description, :icon),
            possible_classifications: category_options(key)
          }
        end,
        top_topics: profile[:top_topics],
        all_talks: @talks.map do |t|
          {
            title: t.title,
            event: t.event&.name,
            event_kind: t.event&.kind,
            date: t.date&.to_s,
            year: t.date&.year,
            kind: t.kind,
            duration_minutes: t.duration_in_seconds ? (t.duration_in_seconds / 60.0).round : nil,
            language: t.language,
            view_count: t.view_count,
            has_slides: t.slides_url.present?,
            topics: t.topics.map(&:name),
            co_speakers: t.speakers.reject { |s| s.id == speaker.id }.map(&:name)
          }
        end,
        events_attended: speaker.participated_events.map do |e|
          {
            name: e.name,
            kind: e.kind,
            location: e.location,
            country: e.country_code,
            date: e.start_date&.to_s
          }
        end,
        in_person_watches: speaker.watched_talks.where(watched_on: "in_person").includes(:talk).map do |wt|
          {
            talk_title: wt.talk.title,
            event: wt.talk.event&.name,
            date: wt.talk.date&.to_s
          }
        end
      }

      JSON.pretty_generate(data)
    end

    def category_options(key)
      case key
      when :title_pattern
        %w[Question\ Asker Builder Journey\ Narrator Provocateur Introducer Deep\ Diver Future\ Gazer Problem\ Solver Neutral]
      when :circuit
        ["Global Nomad", "Regional (e.g. Europe ↔ North America)", "Local (e.g. North America Local)"]
      when :generation
        ["OG (2005-2010)", "Early Rails (2011-2014)", "Modern Era (2015-2018)", "Pre-Pandemic (2019-2021)", "New Wave (2022+)"]
      when :duration
        ["Lightning Specialist", "Short & Sweet", "Standard Format", "Deep Diver", "Keynote Length"]
      when :collaboration
        ["Solo Artist", "Mostly Solo", "Team Player", "Dynamic Duo", "Ensemble Cast"]
      when :seasonal
        ["Winter Specialist", "Spring Specialist", "Summer Specialist", "Fall Specialist", "Year-Round Speaker"]
      when :loyalty
        ["Exclusive", "Loyal Regular", "Conference Hopper", "Multi-Loyalist", "Explorer"]
      when :recycling
        ["Tour Speaker", "Signature Talk", "Occasional Repeat", "Always Fresh"]
      when :trend_timing
        ["Trend Setter", "Early Majority", "Late Majority", "Classics Lover"]
      when :title_evolution
        ["Getting Verbose", "Getting Concise", "Always Punchy", "Always Descriptive", "Stable Middle"]
      when :topic_evolution
        ["Consistent Expert", "Topic Shifter", "Expanding Horizons", "Focused Specialist", "Steady Evolution"]
      when :mentorship
        ["Super Mentor", "Mentor", "Mentee Graduate", "Collaborator", "Independent"]
      when :pioneer
        ["Serial Pioneer", "Pioneer", "First Edition Speaker", "Established Circuit"]
      when :event_kind
        ["Conference Regular", "Community Builder", "Workshop Wizard", "Event Omnivore", "Balanced Speaker", "Mixed Circuit"]
      when :talk_format
        ["Keynote Material", "Speed Demon", "Discussion Leader", "Hands-On Teacher", "Classic Presenter", "Format Flexible"]
      when :topic_breadth
        ["Renaissance Speaker", "Diverse Explorer", "Balanced Expert", "Focused Specialist", "Deep Expert"]
      when :network_size
        ["Super Connector", "Well Connected", "Selective Partner", "Faithful Duo", "Solo Flyer"]
      when :slide_sharing
        ["Open Book", "Generous Sharer", "Selective Sharer", "Occasional Sharer", "Slides Keeper"]
      when :language
        ["Polyglot Speaker", "Trilingual", "Bilingual", "English Speaker", "[Language] Speaker"]
      when :cadence
        ["Rising Star", "Prolific Active", "Steady Active", "Distinguished Alumni", "Peak Behind", "One-Timer", "Occasional Speaker"]
      when :continents
        ["World Traveler", "Globe Trotter", "Multi-Continental", "Two-Continent", "[Continent] Based", "Local"]
      when :popularity
        ["Viral Speaker", "Popular Voice", "Growing Audience", "Solid Following", "Building Audience", "Hidden Gem"]
      when :hallway_track
        ["Session Superfan", "Balanced Attendee", "Hallway Hero", "Social Butterfly", "Hallway Legend"]
      else
        []
      end
    end

    def to_llm_prose(profile)
      categories = profile[:categories].reject { |_, v| v[:label] == "Unknown" }
      stats = profile[:stats]
      topics = profile[:top_topics]

      <<~PROMPT
        Write a fun, engaging 2-3 paragraph profile summary for #{speaker.name} based on the following conference speaking data. Be creative and playful while staying accurate to the data. Use the category labels and descriptions to paint a picture of who they are as a speaker and community member.

        ## Basic Stats
        - Total talks given: #{stats[:total_talks]}
        - Unique events: #{stats[:unique_events]}
        - Unique conference series: #{stats[:unique_series]}
        - Countries spoken in: #{stats[:countries_spoken_in]}
        - Years active: #{stats[:years_active]} (#{stats[:first_talk_year]} - #{stats[:last_talk_year]})
        - Average talk duration: #{stats[:avg_talk_duration]} minutes
        - Topics covered: #{stats[:unique_topics]}

        ## Speaker Categories
        #{categories.map { |key, cat| "- #{CATEGORY_LABELS[key] || key.to_s.titleize}: #{cat[:label]} - #{cat[:description]}" }.join("\n")}

        ## Top Topics
        #{topics.map { |t| "- #{t[:name]} (#{t[:count]} talks)" }.join("\n")}

        ## Sample Talk Titles
        #{@talks.first(5).map { |t| "- \"#{t.title}\" (#{t.event&.name}, #{t.date&.year})" }.join("\n")}

        Write the summary in a warm, celebratory tone that highlights what makes this speaker unique. Focus on their speaking style, geographic reach, topic expertise, and community involvement. Don't just list facts - weave them into a narrative.
      PROMPT
    end

    def compute_categories
      {
        title_pattern: compute_title_pattern,
        circuit: compute_circuit,
        generation: compute_generation,
        duration: compute_duration,
        collaboration: compute_collaboration,
        seasonal: compute_seasonal,
        loyalty: compute_loyalty,
        recycling: compute_recycling,
        trend_timing: compute_trend_timing,
        title_evolution: compute_title_evolution,
        topic_evolution: compute_topic_evolution,
        mentorship: compute_mentorship,
        pioneer: compute_pioneer,
        event_kind: compute_event_kind,
        talk_format: compute_talk_format,
        topic_breadth: compute_topic_breadth,
        network_size: compute_network_size,
        slide_sharing: compute_slide_sharing,
        language: compute_language,
        cadence: compute_cadence,
        continents: compute_continents,
        popularity: compute_popularity,
        hallway_track: compute_hallway_track
      }
    end

    def compute_stats
      {
        total_talks: @talks.count,
        unique_events: @talks.map(&:event_id).compact.uniq.count,
        unique_topics: speaker_topics.count,
        years_active: years_active,
        first_talk_year: first_talk_year,
        last_talk_year: last_talk_year,
        countries_spoken_in: countries.count,
        avg_talk_duration: avg_duration,
        unique_series: series_ids.uniq.count
      }
    end

    def compute_title_pattern
      titles = @talks.map(&:title).compact
      Classifiers::TitleLinguist.classify(titles)
    end

    def compute_circuit
      country_codes = @talks.filter_map { |t| t.event&.country_code }
      Classifiers::CircuitTraveler.classify(country_codes)
    end

    def compute_generation
      Classifiers::Generation.classify(first_talk_year)
    end

    def compute_duration
      durations = @talks.map(&:duration_in_seconds).compact
      Classifiers::DurationDNA.classify(durations)
    end

    def compute_collaboration
      speaker_counts = @talks.map { |t| t.speakers.reject { |s| excluded?(s) }.count }
      Classifiers::CollaborationStyle.classify(speaker_counts)
    end

    def compute_seasonal
      months = @talks.filter_map { |t| t.date&.month }
      Classifiers::SeasonalPattern.classify(months)
    end

    def compute_loyalty
      Classifiers::ConferenceLoyalty.classify(series_ids)
    end

    def compute_recycling
      titles = @talks.map(&:title).compact
      Classifiers::TalkRecycler.classify(titles)
    end

    def compute_trend_timing
      topic_first_year = {}

      TalkTopic.joins(:talk, :topic)
        .where(topics: {status: "approved"})
        .where.not(talks: {date: nil})
        .group("topics.id")
        .pluck(Arel.sql("topics.id, MIN(strftime('%Y', talks.date))"))
        .each { |id, year| topic_first_year[id] = year.to_i }

      early_count = 0
      late_count = 0

      @talks.each do |talk|
        next unless talk.date

        year = talk.date.year
        talk.topics.select { |t| t.status == "approved" }.each do |topic|
          first_year = topic_first_year[topic.id]
          next unless first_year

          years_after = year - first_year
          if years_after <= 1
            early_count += 1
          elsif years_after >= 3
            late_count += 1
          end
        end
      end

      Classifiers::TrendTiming.classify(early_count, late_count)
    end

    def compute_title_evolution
      titles_with_years = @talks.filter_map do |talk|
        next unless talk.date && talk.title.present?
        {year: talk.date.year, word_count: talk.title.split.size}
      end

      Classifiers::TitleEvolution.classify(titles_with_years)
    end

    def compute_topic_evolution
      topics_by_era = {"early" => [], "middle" => [], "recent" => []}

      @talks.each do |talk|
        next unless talk.date

        era = case talk.date.year
        when 2005..2012 then "early"
        when 2013..2017 then "middle"
        when 2018..2030 then "recent"
        else next
        end

        talk.topics.select { |t| t.status == "approved" }.each do |topic|
          topics_by_era[era] << topic.name
        end
      end

      topics_by_era.transform_values!(&:uniq)
      Classifiers::TopicEvolution.classify(topics_by_era)
    end

    def compute_mentorship
      speaker_first = @talks.filter_map(&:date).min

      mentored_names = []
      was_mentored = false
      co_presentations = 0

      @talks.each do |talk|
        speakers = talk.speakers.reject { |s| excluded?(s) }
        next if speakers.size < 2

        co_presentations += 1

        speakers.each do |co_speaker|
          next if co_speaker.id == speaker.id

          co_first = co_speaker.talks.filter_map(&:date).min
          next unless speaker_first && co_first && talk.date

          if talk.date == co_first && speaker_first < co_first
            mentored_names << co_speaker.name
          elsif talk.date == speaker_first && co_first < speaker_first
            was_mentored = true
          end
        end
      end

      Classifiers::MentorshipRole.classify(mentored_names.uniq.size, was_mentored, co_presentations)
    end

    def compute_pioneer
      first_editions = Event.where.not(start_date: nil)
        .group(:event_series_id)
        .minimum(:start_date)

      pioneered = 0
      total_series = Set.new

      @talks.each do |talk|
        next unless talk.event&.event_series_id && talk.event.start_date

        total_series << talk.event.event_series_id
        first_date = first_editions[talk.event.event_series_id]
        next unless first_date

        pioneered += 1 if talk.event.start_date.year == first_date.year
      end

      Classifiers::EventPioneer.classify(pioneered, total_series.size)
    end

    def compute_event_kind
      kinds = @talks.filter_map { |t| t.event&.kind }
      Classifiers::EventKindPreference.classify(kinds)
    end

    def compute_talk_format
      kinds = @talks.map(&:kind).compact
      Classifiers::TalkFormatSpecialist.classify(kinds)
    end

    def compute_topic_breadth
      Classifiers::TopicBreadth.classify(@talks.count, speaker_topics.count)
    end

    def compute_network_size
      unique_collaborators = Set.new
      total_collabs = 0

      @talks.each do |talk|
        co_speakers = talk.speakers.reject { |s| excluded?(s) || s.id == speaker.id }
        co_speakers.each { |s| unique_collaborators << s.id }
        total_collabs += 1 if co_speakers.any?
      end

      Classifiers::NetworkSize.classify(unique_collaborators.size, total_collabs)
    end

    def compute_slide_sharing
      with_slides = @talks.count { |t| t.slides_url.present? }
      Classifiers::SlideSharing.classify(with_slides, @talks.count)
    end

    def compute_language
      languages = @talks.map(&:language).compact
      Classifiers::LanguageDiversity.classify(languages)
    end

    def compute_cadence
      talks_by_year = @talks.filter_map { |t| t.date&.year }.tally
      Classifiers::CareerCadence.classify(talks_by_year)
    end

    def compute_continents
      country_codes = @talks.filter_map { |t| t.event&.country_code }
      Classifiers::ContinentCoverage.classify(country_codes)
    end

    def compute_popularity
      total_views = @talks.sum { |t| t.view_count || 0 }
      Classifiers::ViewPopularity.classify(total_views, @talks.count)
    end

    def compute_hallway_track
      in_person_watches = speaker.watched_talks.where(watched_on: "in_person")
      return Classifiers::HallwayTrack.classify([]) if in_person_watches.none?

      participated_events = speaker.participated_events.includes(:talks)
      return Classifiers::HallwayTrack.classify([]) if participated_events.empty?

      in_person_talk_ids = in_person_watches.pluck(:talk_id).to_set

      attendance_data = participated_events.filter_map do |event|
        next if event.talks_count == 0

        watched_in_person = event.talks.count { |t| in_person_talk_ids.include?(t.id) }

        max_possible = Classifiers::HallwayTrack.max_possible_talks(event)

        next if max_possible == 0

        {
          event_id: event.id,
          event_name: event.name,
          watched_in_person: watched_in_person,
          max_possible: max_possible
        }
      end

      Classifiers::HallwayTrack.classify(attendance_data)
    end

    def speaker_topics
      @speaker_topics ||= @talks.flat_map(&:topics).uniq
    end

    def top_topics(limit = 5)
      @talks.flat_map(&:topics)
        .tally
        .sort_by { |_, count| -count }
        .first(limit)
        .map { |topic, count| {name: topic.name, slug: topic.slug, count: count} }
    end

    def countries
      @countries ||= @talks.filter_map { |t| t.event&.country_code }.tally
    end

    def series_ids
      @series_ids ||= @talks.filter_map { |t| t.event&.event_series_id }
    end

    def years_active
      years = @talks.filter_map { |t| t.date&.year }.uniq

      return 0 if years.empty?

      years.max - years.min + 1
    end

    def first_talk_year
      @talks.filter_map { |t| t.date&.year }.min
    end

    def last_talk_year
      @talks.filter_map { |t| t.date&.year }.max
    end

    def avg_duration
      durations = @talks.filter_map { |t| t.duration_in_seconds if t.duration_in_seconds&.positive? }
      return nil if durations.empty?
      (durations.sum / durations.count / 60.0).round
    end

    def excluded?(speaker)
      Classifiers::EXCLUDED_SPEAKERS.map(&:downcase).include?(speaker.name&.downcase)
    end
  end
end
