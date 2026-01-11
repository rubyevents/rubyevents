# frozen_string_literal: true

module EventSeries::TypesenseSearchable
  extend ActiveSupport::Concern

  included do
    include ::Typesense

    typesense enqueue: :trigger_typesense_job, if: :should_index?, disable_indexing: -> { Search::Backend.skip_indexing } do
      attributes :name, :slug, :website, :twitter

      attribute :description_text do
        read_attribute(:description)
      end

      attribute :kind
      attribute :frequency

      attribute :events_count do
        Event.where(event_series_id: id).count
      end

      attribute :talks_count do
        Event.where(event_series_id: id).sum(:talks_count)
      end

      attribute :avatar_path do
        Event.where(event_series_id: id).order(date: :desc).first&.avatar_image_path
      end

      attribute :start_year do
        Event.where(event_series_id: id).minimum(:date)&.year
      end

      attribute :end_year do
        Event.where(event_series_id: id).maximum(:date)&.year
      end

      attribute :alias_names do
        ::Alias.where(aliasable_type: "EventSeries", aliasable_id: id).pluck(:name)
      end

      attribute :alias_slugs do
        ::Alias.where(aliasable_type: "EventSeries", aliasable_id: id).pluck(:slug)
      end

      predefined_fields [
        {"name" => "name", "type" => "string"},
        {"name" => "description_text", "type" => "string", "optional" => true},
        {"name" => "slug", "type" => "string"},

        {"name" => "kind", "type" => "string", "facet" => true},
        {"name" => "frequency", "type" => "string", "facet" => true},
        {"name" => "website", "type" => "string", "optional" => true},
        {"name" => "twitter", "type" => "string", "optional" => true},

        {"name" => "events_count", "type" => "int32"},
        {"name" => "talks_count", "type" => "int32"},

        {"name" => "avatar_path", "type" => "string", "optional" => true},
        {"name" => "start_year", "type" => "int32", "optional" => true},
        {"name" => "end_year", "type" => "int32", "optional" => true},

        {"name" => "alias_names", "type" => "string[]", "optional" => true},
        {"name" => "alias_slugs", "type" => "string[]", "optional" => true}
      ]

      default_sorting_field "talks_count"

      multi_way_synonyms [
        {"railsconf-synonym" => %w[railsconf rails-conf]},
        {"rubyconf-synonym" => %w[rubyconf ruby-conf]},
        {"euruko-synonym" => %w[euruko european-ruby-konferenz]},
        {"rubykaigi-synonym" => %w[rubykaigi ruby-kaigi]}
      ]

      token_separators %w[- _]
    end
  end

  class_methods do
    def trigger_typesense_job(record, remove)
      TypesenseIndexJob.perform_later(record, remove ? "typesense_remove_from_index!" : "typesense_index!")
    end

    def typesense_search_series(query, options = {})
      query_by_fields = "name,slug,description_text,alias_names,alias_slugs"

      search_options = {
        query_by_weights: "10,9,3,8,7",
        per_page: options[:per_page] || 20,
        page: options[:page] || 1,
        highlight_full_fields: "name",
        highlight_affix_num_tokens: 10
      }

      filters = []
      filters << "kind:=#{options[:kind]}" if options[:kind].present?
      filters << "frequency:=#{options[:frequency]}" if options[:frequency].present?

      search_options[:filter_by] = filters.join(" && ") if filters.any?

      sort_options = {
        "talks" => "talks_count:desc",
        "events" => "events_count:desc",
        "name" => "name:asc",
        "relevance" => "_text_match:desc,talks_count:desc"
      }

      search_options[:sort_by] = sort_options[options[:sort]] || sort_options["relevance"]

      search(query.presence || "*", query_by_fields, search_options)
    end
  end

  private

  def should_index?
    Event.where(event_series_id: id).exists?
  end
end
