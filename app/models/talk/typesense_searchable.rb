# frozen_string_literal: true

module Talk::TypesenseSearchable
  extend ActiveSupport::Concern

  included do
    include ::Typesense

    typesense enqueue: :trigger_typesense_job, if: :should_index? do
      attributes :title, :description, :summary, :slug, :language, :kind

      attribute :date_timestamp do
        date&.to_time&.to_i || 0
      end

      attribute :published_at_timestamp do
        published_at&.to_i || 0
      end

      attribute :year do
        date&.year
      end

      # Recency score for boosting recent talks (higher = more recent)
      # Calculated as days since epoch, so recent talks have higher scores
      # Days since 2020-01-01, capped to ensure older talks still have some score
      attribute :recency_score do
        return 0 unless date

        days_since_2020 = (date.to_date - Date.new(2020, 1, 1)).to_i

        [days_since_2020, 0].max
      end

      attribute :video_provider
      attribute :video_id
      attribute :duration_in_seconds
      attribute :view_count
      attribute :like_count

      attribute :thumbnail_url do
        thumbnail_md
      end

      attribute :speakers do
        speakers.map do |speaker|
          {
            id: speaker.id,
            name: speaker.name,
            slug: speaker.slug,
            github: speaker.github_handle,
            twitter: speaker.twitter
          }
        end
      end

      attribute :speaker_names do
        speakers.pluck(:name).join(", ")
      end

      attribute :speaker_slugs do
        speakers.pluck(:slug)
      end

      attribute :speaker_github_handles do
        speakers.pluck(:github_handle).compact
      end

      attribute :speaker_twitter_handles do
        speakers.pluck(:twitter).compact
      end

      attribute :speaker_alias_names do
        speakers.flat_map { |s| s.aliases.pluck(:name) }.compact
      end

      attribute :speaker_alias_slugs do
        speakers.flat_map { |s| s.aliases.pluck(:slug) }.compact
      end

      attribute :event do
        next nil unless event

        {
          id: event.id,
          name: event.name,
          slug: event.slug,
          kind: event.kind,
          city: event.city,
          country_code: event.country_code
        }
      end

      attribute :event_name do
        event&.name
      end

      attribute :event_slug do
        event&.slug
      end

      attribute :series_name do
        event&.series&.name
      end

      attribute :series_slug do
        event&.series&.slug
      end

      attribute :event_alias_names do
        event&.slug_aliases&.pluck(:name) || []
      end

      attribute :series_alias_names do
        event&.series&.aliases&.pluck(:name) || []
      end

      attribute :country_code do
        event&.country_code
      end

      attribute :country_name do
        event&.country&.common_name || event&.country&.iso_short_name
      end

      attribute :state do
        event&.state
      end

      attribute :state_name do
        event&.state_object&.name
      end

      attribute :city do
        event&.city
      end

      attribute :continent do
        event&.country&.continent
      end

      attribute :location do
        location
      end

      attribute :topics do
        approved_topics.map do |topic|
          {
            id: topic.id,
            name: topic.name,
            slug: topic.slug
          }
        end
      end

      attribute :topic_names do
        approved_topics.pluck(:name)
      end

      attribute :topic_slugs do
        approved_topics.pluck(:slug)
      end

      attribute :transcript_text do
        talk_transcript&.transcript&.to_text&.truncate(100_000)
      end

      attribute :has_slides do
        slides_url.present?
      end

      attribute :slides_url

      attribute :has_transcript do
        talk_transcript&.raw_transcript.present?
      end

      attribute :resource_names do
        (additional_resources || []).map { |r| r["name"] }.compact
      end

      attribute :resource_urls do
        (additional_resources || []).map { |r| r["url"] }.compact
      end

      attribute :resource_types do
        (additional_resources || []).map { |r| r["type"] }.compact.uniq
      end

      attribute :alias_slugs do
        aliases.pluck(:slug)
      end

      predefined_fields [
        {"name" => "title", "type" => "string"},
        {"name" => "description", "type" => "string", "optional" => true},
        {"name" => "summary", "type" => "string", "optional" => true},
        {"name" => "transcript_text", "type" => "string", "optional" => true},

        {"name" => "speaker_names", "type" => "string", "optional" => true},
        {"name" => "speaker_slugs", "type" => "string[]", "optional" => true},
        {"name" => "speaker_github_handles", "type" => "string[]", "optional" => true},
        {"name" => "speaker_twitter_handles", "type" => "string[]", "optional" => true},
        {"name" => "speaker_alias_names", "type" => "string[]", "optional" => true},
        {"name" => "speaker_alias_slugs", "type" => "string[]", "optional" => true},
        {"name" => "speakers", "type" => "object[]", "optional" => true},

        {"name" => "event_name", "type" => "string", "optional" => true, "facet" => true},
        {"name" => "event_slug", "type" => "string", "optional" => true},
        {"name" => "event_alias_names", "type" => "string[]", "optional" => true},
        {"name" => "series_name", "type" => "string", "optional" => true, "facet" => true},
        {"name" => "series_slug", "type" => "string", "optional" => true},
        {"name" => "series_alias_names", "type" => "string[]", "optional" => true},
        {"name" => "event", "type" => "object", "optional" => true},

        {"name" => "topic_names", "type" => "string[]", "optional" => true, "facet" => true},
        {"name" => "topic_slugs", "type" => "string[]", "optional" => true},
        {"name" => "topics", "type" => "object[]", "optional" => true},

        {"name" => "kind", "type" => "string", "facet" => true},
        {"name" => "language", "type" => "string", "facet" => true},
        {"name" => "year", "type" => "int32", "optional" => true, "facet" => true},
        {"name" => "video_provider", "type" => "string", "facet" => true},
        {"name" => "country_code", "type" => "string", "optional" => true, "facet" => true},
        {"name" => "country_name", "type" => "string", "optional" => true, "facet" => true},
        {"name" => "state", "type" => "string", "optional" => true, "facet" => true},
        {"name" => "state_name", "type" => "string", "optional" => true},
        {"name" => "city", "type" => "string", "optional" => true, "facet" => true},
        {"name" => "continent", "type" => "string", "optional" => true, "facet" => true},
        {"name" => "location", "type" => "string", "optional" => true},
        {"name" => "has_slides", "type" => "bool"},
        {"name" => "has_transcript", "type" => "bool"},

        {"name" => "date_timestamp", "type" => "int64"},
        {"name" => "published_at_timestamp", "type" => "int64"},
        {"name" => "recency_score", "type" => "int32"},
        {"name" => "view_count", "type" => "int32", "optional" => true},
        {"name" => "like_count", "type" => "int32", "optional" => true},
        {"name" => "duration_in_seconds", "type" => "int32", "optional" => true},

        {"name" => "slug", "type" => "string"},
        {"name" => "video_id", "type" => "string", "optional" => true},
        {"name" => "thumbnail_url", "type" => "string", "optional" => true},
        {"name" => "slides_url", "type" => "string", "optional" => true},
        {"name" => "alias_slugs", "type" => "string[]", "optional" => true},

        {"name" => "resource_names", "type" => "string[]", "optional" => true},
        {"name" => "resource_urls", "type" => "string[]", "optional" => true},
        {"name" => "resource_types", "type" => "string[]", "optional" => true, "facet" => true}
      ]

      default_sorting_field "date_timestamp"

      enable_nested_fields true

      multi_way_synonyms [
        {"rails-synonym" => %w[rails ruby-on-rails rubyonrails ror]},
        {"rspec-synonym" => %w[rspec r-spec]},
        {"activerecord-synonym" => %w[activerecord active-record ar]},
        {"actioncable-synonym" => %w[actioncable action-cable websockets]},
        {"hotwire-synonym" => %w[hotwire turbo stimulus]},
        {"testing-synonym" => %w[testing tests test tdd bdd]},
        {"performance-synonym" => %w[performance optimization speed fast]},
        {"security-synonym" => %w[security secure authentication authorization]},
        {"api-synonym" => %w[api apis rest restful graphql]},
        {"database-synonym" => %w[database db databases sql postgresql postgres mysql sqlite]},
        {"docker-synonym" => %w[docker containers containerization kubernetes k8s]},
        {"ci-synonym" => %w[ci cd continuous-integration continuous-deployment github-actions circleci]},
        {"aws-synonym" => %w[aws amazon-web-services cloud heroku digitalocean]},
        {"frontend-synonym" => %w[frontend front-end javascript js typescript ts react vue angular]},

        {"keynote-synonym" => %w[keynote keynotes opening-keynote closing-keynote]},
        {"lightning-talk-synonym" => %w[lightning_talk lightning-talk lightning talks short-talk]},
        {"workshop-synonym" => %w[workshop workshops hands-on tutorial]},
        {"panel-synonym" => %w[panel panels discussion roundtable]},
        {"interview-synonym" => %w[interview interviews fireside_chat fireside chat conversation]},
        {"demo-synonym" => %w[demo demos demonstration live-coding livecoding]}
      ]

      one_way_synonyms Talk.typesense_synonyms_from_aliases

      symbols_to_index %w[# @ $]

      token_separators %w[- _]
    end
  end

  class_methods do
    def typesense_synonyms_from_aliases
      ::Alias.where(aliasable_type: "User")
        .includes(:aliasable)
        .group_by(&:aliasable)
        .filter_map do |user, aliases|
          next unless user

          canonical_slug = user.name.parameterize
          alias_slugs = aliases.map { |a| a.name.parameterize }.uniq - [canonical_slug]

          next if alias_slugs.empty?

          {"#{canonical_slug}-synonym" => {"root" => canonical_slug, "synonyms" => alias_slugs}}
        end
    rescue ActiveRecord::StatementInvalid
      []
    end

    def trigger_typesense_job(record, remove)
      TypesenseIndexJob.perform_later(record, remove ? "typesense_remove_from_index!" : "typesense_index!")
    end

    def typesense_search_talks(query, options = {})
      query_by_fields = "title,slug,summary,description,kind,speaker_names,speaker_alias_names,speaker_github_handles,speaker_twitter_handles,event_name,event_alias_names,series_name,series_alias_names,topic_names,resource_names,city,country_name,state_name,continent,location,transcript_text"

      search_options = {
        query_by_weights: "10,9,5,3,3,8,7,9,9,4,4,4,4,6,7,3,3,2,2,2,1",
        per_page: options[:per_page] || 20,
        page: options[:page] || 1,
        highlight_full_fields: "title,summary",
        highlight_affix_num_tokens: 10
      }

      filters = []
      filters << "kind:=#{options[:kind]}" if options[:kind].present?
      filters << "language:=#{options[:language]}" if options[:language].present?
      filters << "year:=#{options[:year]}" if options[:year].present?
      filters << "event_slug:=#{options[:event_slug]}" if options[:event_slug].present?
      filters << "series_slug:=#{options[:series_slug]}" if options[:series_slug].present?
      filters << "topic_slugs:=#{options[:topic_slug]}" if options[:topic_slug].present?
      filters << "speaker_slugs:=#{options[:speaker_slug]}" if options[:speaker_slug].present?
      filters << "has_transcript:=true" if options[:has_transcript]
      filters << "has_slides:=true" if options[:has_slides]
      filters << "country_code:=#{options[:country_code]}" if options[:country_code].present?
      filters << "state:=#{options[:state]}" if options[:state].present?
      filters << "city:=#{options[:city]}" if options[:city].present?
      filters << "continent:=#{options[:continent]}" if options[:continent].present?

      search_options[:filter_by] = filters.join(" && ") if filters.any?

      sort_options = {
        "date" => "date_timestamp:desc",
        "date_desc" => "date_timestamp:desc",
        "date_asc" => "date_timestamp:asc",
        "created_at_desc" => "date_timestamp:desc",
        "created_at_asc" => "date_timestamp:asc",
        "views" => "view_count:desc",
        "duration" => "duration_in_seconds:desc",
        "relevance" => "_text_match:desc,recency_score:desc,date_timestamp:desc"
      }

      search_options[:sort_by] = sort_options[options[:sort]] || sort_options["relevance"]

      if options[:facets]
        search_options[:facet_by] = options[:facets].join(",")
        search_options[:max_facet_values] = options[:max_facet_values] || 10
      end

      search(query.presence || "*", query_by_fields, search_options)
    end
  end

  private

  def should_index?
    true
  end
end
