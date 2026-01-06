# frozen_string_literal: true

class Search::Backend::SQLiteFTS
  class << self
    def search_talks(query, limit:, **options)
      talks = Talk.includes(:speakers, event: :series)
      talks = talks.ft_search(query).with_snippets if query.present?
      talks = talks.for_topic(options[:topic_slug]) if options[:topic_slug].present?
      talks = talks.for_event(options[:event_slug]) if options[:event_slug].present?
      talks = talks.for_speaker(options[:speaker_slug]) if options[:speaker_slug].present?
      talks = talks.where(kind: options[:kind]) if options[:kind].present?
      talks = talks.where(language: options[:language]) if options[:language].present?
      talks = talks.ft_watchable unless options[:include_unwatchable]

      total_count = talks.except(:select).count

      [talks.limit(limit), total_count]
    end

    def search_talks_with_pagy(query, pagy_backend:, **options)
      talks = Talk.includes(:speakers, event: :series, child_talks: :speakers)
      talks = talks.ft_search(query).with_snippets if query.present?
      talks = talks.for_topic(options[:topic_slug]) if options[:topic_slug].present?
      talks = talks.for_event(options[:event_slug]) if options[:event_slug].present?
      talks = talks.for_speaker(options[:speaker_slug]) if options[:speaker_slug].present?
      talks = talks.where(kind: options[:kind]) if options[:kind].present?
      talks = talks.where(language: options[:language]) if options[:language].present?
      talks = talks.where("created_at >= ?", options[:created_after]) if options[:created_after].present?
      talks = talks.ft_watchable unless options[:include_unwatchable]
      talks = talks.scheduled if options[:status] == "scheduled"

      talks = apply_sort(talks, query, options[:sort])

      pagy_options = {
        limit: options[:per_page] || 20,
        page: options[:page] || 1
      }.compact_blank

      pagy_backend.send(:pagy, talks, **pagy_options)
    end

    def search_speakers(query, limit:)
      speakers = User.speakers.canonical.ft_search(query).with_snippets.ranked
      total_count = speakers.except(:select).count

      [speakers.limit(limit), total_count]
    end

    def search_events(query, limit:)
      events = Event.includes(:series).canonical.ft_search(query)
      total_count = events.except(:select).count

      [events.limit(limit), total_count]
    end

    def search_topics(query, limit:)
      topics = Topic.approved.canonical.with_talks.order(talks_count: :desc)
      topics = topics.where("name LIKE ?", "%#{query}%")
      total_count = topics.count

      [topics.limit(limit), total_count]
    end

    def search_series(query, limit:)
      series = EventSeries.joins(:events).distinct.order(name: :asc)
      series = series.where("event_series.name LIKE ?", "%#{query}%")
      total_count = series.count

      [series.limit(limit), total_count]
    end

    def search_organizations(query, limit:)
      organizations = Organization.joins(:sponsors).distinct.order(name: :asc)
      organizations = organizations.where("organizations.name LIKE ?", "%#{query}%")
      total_count = organizations.count

      [organizations.limit(limit), total_count]
    end

    def search_languages(query, limit:)
      return [[], 0] if query.blank?

      results = []
      query_downcase = query.downcase

      languages_with_talks.each do |language_code, talk_count|
        language_name = Language.by_code(language_code)
        next unless language_name

        if language_name.downcase.include?(query_downcase) ||
            language_code.downcase.include?(query_downcase)
          results << {
            code: language_code,
            name: language_name,
            talk_count: talk_count
          }
        end
      end

      sorted = results.sort_by do |r|
        exact_match = (r[:name].downcase == query_downcase) ? 0 : 1
        starts_with = r[:name].downcase.start_with?(query_downcase) ? 0 : 1

        [exact_match, starts_with, -r[:talk_count]]
      end.first(limit)

      [sorted, sorted.size]
    end

    def search_locations(query, limit:)
      return [[], 0] if query.blank?

      results = []
      query_downcase = query.downcase

      countries_with_events.each do |country_code, event_count|
        country = Country.find(country_code)
        next unless country

        country_name = country.common_name || country.iso_short_name

        if country_name.downcase.include?(query_downcase) ||
            country_code.downcase.include?(query_downcase)
          results << {
            type: :country,
            name: country_name,
            country_code: country_code,
            emoji_flag: country.emoji_flag,
            event_count: event_count
          }
        end
      end

      cities_with_countries.each do |city, country_code, event_count|
        country = Country.find(country_code)
        country_name = country&.common_name || country&.iso_short_name || country_code

        if city.downcase.include?(query_downcase)
          results << {
            type: :city,
            name: city,
            country_name: country_name,
            country_code: country_code,
            emoji_flag: country&.emoji_flag,
            event_count: event_count
          }
        end
      end

      sorted = results.sort_by do |r|
        name = r[:name]
        exact_match = (name.downcase == query_downcase) ? 0 : 1
        starts_with = name.downcase.start_with?(query_downcase) ? 0 : 1

        [exact_match, starts_with, -r[:event_count]]
      end.first(limit)

      [sorted, sorted.size]
    end

    def available?
      true
    end

    def name
      :sqlite_fts
    end

    def indexer
      Indexer
    end

    def reset_cache!
      @languages_with_talks = nil
      @countries_with_events = nil
      @cities_with_countries = nil
    end

    private

    SORT_OPTIONS = {
      "date" => "talks.date DESC",
      "date_desc" => "talks.date DESC",
      "date_asc" => "talks.date ASC",
      "created_at_desc" => "talks.created_at DESC",
      "created_at_asc" => "talks.created_at ASC"
    }.freeze

    def apply_sort(talks, query, sort)
      case sort
      when "relevance", "ranked"
        query.present? ? talks.ranked : talks.order("talks.date DESC")
      when *SORT_OPTIONS.keys
        talks.order(SORT_OPTIONS[sort])
      else
        talks.order("talks.date DESC")
      end
    end

    def languages_with_talks
      @languages_with_talks ||= Talk.where.not(language: [nil, "", "en"])
        .group(:language)
        .count
    end

    def countries_with_events
      @countries_with_events ||= Event.where.not(country_code: [nil, ""])
        .group(:country_code)
        .count
    end

    def cities_with_countries
      @cities_with_countries ||= Event.where.not(city: [nil, ""])
        .where.not(country_code: [nil, ""])
        .group(:city, :country_code)
        .count
        .map { |(city, country_code), count| [city, country_code, count] }
    end
  end
end
