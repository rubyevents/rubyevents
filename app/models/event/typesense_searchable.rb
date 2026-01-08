# frozen_string_literal: true

module Event::TypesenseSearchable
  extend ActiveSupport::Concern

  included do
    include ::Typesense

    typesense enqueue: :trigger_typesense_job, if: :should_index? do
      attributes :name, :slug, :kind, :website

      attribute :start_date_timestamp do
        start_date&.to_time&.to_i || 0
      end

      attribute :end_date_timestamp do
        end_date&.to_time&.to_i || 0
      end

      attribute :year do
        start_date&.year
      end

      attribute :formatted_dates
      attributes :city, :country_code
      attribute :country_code

      attribute :location do
        [city, country_code].compact.join(", ")
      end

      attribute :coordinates do
        if latitude.present? && longitude.present?
          [latitude.to_f, longitude.to_f]
        end
      end

      attribute :series do
        {
          id: series.id,
          name: series.name,
          slug: series.slug
        }
      end

      attribute :series_name do
        series.name
      end

      attribute :series_slug do
        series.slug
      end

      attribute :talks_count

      attribute :speakers_count do
        speakers.count
      end

      # Images
      attribute :card_image_path
      attribute :avatar_image_path

      attribute :alias_names do
        slug_aliases.pluck(:name)
      end

      attribute :alias_slugs do
        slug_aliases.pluck(:slug)
      end

      attribute :series_alias_names do
        series&.aliases&.pluck(:name) || []
      end

      attribute :series_alias_slugs do
        series&.aliases&.pluck(:slug) || []
      end

      attribute :keynote_speaker_names do
        keynote_speakers.pluck(:name)
      end

      attribute :topic_names do
        topics.approved.distinct.pluck(:name)
      end

      attribute :talk_languages do
        talks.where.not(language: [nil, ""]).distinct.pluck(:language)
      end

      attribute :talk_language_names do
        talks.where.not(language: [nil, ""]).distinct.pluck(:language).map { |code| Language.by_code(code) }.compact
      end

      attribute :description

      predefined_fields [
        {"name" => "name", "type" => "string"},
        {"name" => "description", "type" => "string", "optional" => true},
        {"name" => "series_name", "type" => "string", "optional" => true},
        {"name" => "alias_names", "type" => "string[]", "optional" => true},
        {"name" => "series_alias_names", "type" => "string[]", "optional" => true},
        {"name" => "series_alias_slugs", "type" => "string[]", "optional" => true},
        {"name" => "keynote_speaker_names", "type" => "string[]", "optional" => true},
        {"name" => "topic_names", "type" => "string[]", "optional" => true},
        {"name" => "talk_languages", "type" => "string[]", "optional" => true, "facet" => true},
        {"name" => "talk_language_names", "type" => "string[]", "optional" => true},

        {"name" => "kind", "type" => "string", "facet" => true},
        {"name" => "year", "type" => "int32", "optional" => true, "facet" => true},
        {"name" => "country_code", "type" => "string", "optional" => true, "facet" => true},
        {"name" => "country_name", "type" => "string", "optional" => true, "facet" => true},
        {"name" => "city", "type" => "string", "optional" => true, "facet" => true},
        {"name" => "series_slug", "type" => "string", "optional" => true, "facet" => true},

        {"name" => "start_date_timestamp", "type" => "int64"},
        {"name" => "end_date_timestamp", "type" => "int64"},
        {"name" => "talks_count", "type" => "int32"},
        {"name" => "speakers_count", "type" => "int32"},

        {"name" => "slug", "type" => "string"},
        {"name" => "website", "type" => "string", "optional" => true},
        {"name" => "location", "type" => "string", "optional" => true},
        {"name" => "formatted_dates", "type" => "string", "optional" => true},
        {"name" => "card_image_path", "type" => "string", "optional" => true},
        {"name" => "avatar_image_path", "type" => "string", "optional" => true},
        {"name" => "alias_slugs", "type" => "string[]", "optional" => true},
        {"name" => "series", "type" => "object", "optional" => true},

        {"name" => "coordinates", "type" => "geopoint", "optional" => true}
      ]

      default_sorting_field "start_date_timestamp"

      enable_nested_fields true

      multi_way_synonyms [
        {"conference-synonym" => %w[conference conf conferences]},
        {"meetup-synonym" => %w[meetup meetups meet-up usergroup user-group]},
        {"workshop-synonym" => %w[workshop workshops hands-on training]},
        {"retreat-synonym" => %w[retreat retreats unconference unconf]},
        {"hackathon-synonym" => %w[hackathon hackathons hack-day hackday]},
        {"rubyconf-synonym" => %w[rubyconf ruby-conf ruby-conference]},
        {"railsconf-synonym" => %w[railsconf rails-conf rails-conference]}
      ]
    end
  end

  class_methods do
    def trigger_typesense_job(record, remove)
      TypesenseIndexJob.perform_later(record, remove ? "typesense_remove_from_index!" : "typesense_index!")
    end

    def typesense_search_events(query, options = {})
      query_by_fields = "name,description,series_name,series_slug,alias_names,alias_slugs,series_alias_names,series_alias_slugs,keynote_speaker_names,topic_names,talk_language_names,kind,city,country_name"

      search_options = {
        query_by_weights: "10,3,8,7,5,5,6,6,4,3,3,3,2,2",
        per_page: options[:per_page] || 20,
        page: options[:page] || 1
      }

      filters = []
      filters << "kind:=#{options[:kind]}" if options[:kind].present?
      filters << "year:=#{options[:year]}" if options[:year].present?
      filters << "country_code:=#{options[:country_code]}" if options[:country_code].present?
      filters << "series_slug:=#{options[:series_slug]}" if options[:series_slug].present?

      if options[:upcoming]
        filters << "start_date_timestamp:>=#{Time.current.to_i}"
      end

      if options[:past]
        filters << "end_date_timestamp:<#{Time.current.to_i}"
      end

      search_options[:filter_by] = filters.join(" && ") if filters.any?

      sort_options = {
        "date" => "start_date_timestamp:desc",
        "date_asc" => "start_date_timestamp:asc",
        "talks" => "talks_count:desc",
        "relevance" => "_text_match:desc,start_date_timestamp:desc"
      }
      search_options[:sort_by] = sort_options[options[:sort]] || sort_options["date"]

      if options[:facets]
        search_options[:facet_by] = options[:facets].join(",")
      end

      search(query.presence || "*", query_by_fields, search_options)
    end
  end

  private

  def should_index?
    canonical_id.nil?
  end
end
