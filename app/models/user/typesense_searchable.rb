# frozen_string_literal: true

module User::TypesenseSearchable
  extend ActiveSupport::Concern

  included do
    include ::Typesense

    typesense enqueue: :trigger_typesense_job, if: :should_index? do
      attributes :name, :slug, :bio, :location

      attributes :github_handle, :twitter, :bsky, :mastodon, :linkedin, :speakerdeck, :website

      attribute :pronouns_display do
        case pronouns_type
        when "custom"
          pronouns
        when "not_specified", "dont_specify"
          nil
        else
          pronouns_type&.tr("_", "/")
        end
      end

      attribute :talks_count

      attribute :events_count do
        events.count
      end

      attribute :avatar_url do
        github_metadata&.dig("avatar_url")
      end

      attribute :alias_names do
        aliases.pluck(:name)
      end

      attribute :alias_slugs do
        aliases.pluck(:slug)
      end

      attribute :topic_names do
        topics.approved.distinct.pluck(:name)
      end

      attribute :topic_slugs do
        topics.approved.distinct.pluck(:slug)
      end

      attribute :event_names do
        events.distinct.pluck(:name)
      end

      attribute :event_series_names do
        events.joins(:series).distinct.pluck("event_series.name")
      end

      attribute :recent_talk_titles do
        talks.order(date: :desc).limit(10).pluck(:title)
      end

      attribute :countries_presented do
        events.distinct.where.not(country_code: nil).pluck(:country_code)
      end

      attribute :verified

      predefined_fields [
        {"name" => "name", "type" => "string"},
        {"name" => "bio", "type" => "string", "optional" => true},
        {"name" => "location", "type" => "string", "optional" => true},
        {"name" => "alias_names", "type" => "string[]", "optional" => true},
        {"name" => "topic_names", "type" => "string[]", "optional" => true},
        {"name" => "event_names", "type" => "string[]", "optional" => true},
        {"name" => "event_series_names", "type" => "string[]", "optional" => true},
        {"name" => "recent_talk_titles", "type" => "string[]", "optional" => true},

        {"name" => "github_handle", "type" => "string", "optional" => true},
        {"name" => "twitter", "type" => "string", "optional" => true},
        {"name" => "bsky", "type" => "string", "optional" => true},
        {"name" => "mastodon", "type" => "string", "optional" => true},
        {"name" => "linkedin", "type" => "string", "optional" => true},
        {"name" => "speakerdeck", "type" => "string", "optional" => true},
        {"name" => "website", "type" => "string", "optional" => true},

        {"name" => "topic_slugs", "type" => "string[]", "optional" => true, "facet" => true},
        {"name" => "countries_presented", "type" => "string[]", "optional" => true, "facet" => true},
        {"name" => "verified", "type" => "bool", "facet" => true},

        {"name" => "talks_count", "type" => "int32"},
        {"name" => "events_count", "type" => "int32"},

        {"name" => "slug", "type" => "string"},
        {"name" => "pronouns_display", "type" => "string", "optional" => true},
        {"name" => "avatar_url", "type" => "string", "optional" => true},
        {"name" => "alias_slugs", "type" => "string[]", "optional" => true}
      ]

      default_sorting_field "talks_count"

      one_way_synonyms User.typesense_synonyms_from_aliases
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

    def typesense_search_speakers(query, options = {})
      query_by_fields = "name,slug,bio,location,alias_names,alias_slugs,github_handle,twitter,topic_names,event_names,recent_talk_titles"

      search_options = {
        query_by_weights: "10,9,3,4,8,7,5,5,4,3,2",
        per_page: options[:per_page] || 20,
        page: options[:page] || 1
      }

      filters = []
      filters << "topic_slugs:=#{options[:topic_slug]}" if options[:topic_slug].present?
      filters << "countries_presented:=#{options[:country_code]}" if options[:country_code].present?
      filters << "verified:=true" if options[:verified]
      filters << "talks_count:>0" unless options[:include_non_speakers]

      search_options[:filter_by] = filters.join(" && ") if filters.any?

      sort_options = {
        "talks" => "talks_count:desc",
        "events" => "events_count:desc",
        "name" => "name:asc",
        "relevance" => "_text_match:desc,talks_count:desc"
      }

      search_options[:sort_by] = sort_options[options[:sort]] || sort_options["relevance"]

      if options[:facets]
        search_options[:facet_by] = options[:facets].join(",")
      end

      search(query.presence || "*", query_by_fields, search_options)
    end
  end

  private

  def should_index?
    indexable?
  end
end
