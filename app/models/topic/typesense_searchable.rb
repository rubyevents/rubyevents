# frozen_string_literal: true

module Topic::TypesenseSearchable
  extend ActiveSupport::Concern

  included do
    include ::Typesense

    typesense enqueue: :trigger_typesense_job, if: :should_index?, disable_indexing: -> { Search::Backend.skip_indexing } do
      attributes :name, :description, :slug
      attribute :status

      attribute :talks_count

      attribute :published

      attribute :talk_titles do
        talks.limit(10).pluck(:title)
      end

      attribute :talk_slugs do
        talks.limit(50).pluck(:slug)
      end

      predefined_fields [
        {"name" => "name", "type" => "string"},
        {"name" => "description", "type" => "string", "optional" => true},
        {"name" => "slug", "type" => "string"},

        {"name" => "status", "type" => "string", "facet" => true},
        {"name" => "published", "type" => "bool"},
        {"name" => "talks_count", "type" => "int32"},

        {"name" => "talk_titles", "type" => "string[]", "optional" => true},
        {"name" => "talk_slugs", "type" => "string[]", "optional" => true}
      ]

      default_sorting_field "talks_count"

      multi_way_synonyms [
        {"rails-synonym" => %w[rails ruby-on-rails rubyonrails ror]},
        {"hotwire-synonym" => %w[hotwire turbo stimulus turbolinks]},
        {"testing-synonym" => %w[testing tests test tdd bdd rspec minitest]},
        {"performance-synonym" => %w[performance optimization speed fast profiling]},
        {"security-synonym" => %w[security secure authentication authorization oauth]},
        {"api-synonym" => %w[api apis rest restful graphql json]},
        {"database-synonym" => %w[database db databases sql postgresql postgres mysql sqlite activerecord]},
        {"frontend-synonym" => %w[frontend front-end javascript js typescript css html]},
        {"devops-synonym" => %w[devops deployment deploy docker kubernetes ci cd]},
        {"gem-synonym" => %w[gem gems rubygems library libraries]}
      ]

      token_separators %w[- _]
    end
  end

  class_methods do
    def trigger_typesense_job(record, remove)
      TypesenseIndexJob.perform_later(record, remove ? "typesense_remove_from_index!" : "typesense_index!")
    end

    def typesense_search_topics(query, options = {})
      query_by_fields = "name,description"

      search_options = {
        query_by_weights: "10,3",
        per_page: options[:per_page] || 20,
        page: options[:page] || 1,
        highlight_full_fields: "name",
        highlight_affix_num_tokens: 10
      }

      filters = []
      filters << "status:=approved" unless options[:include_all_statuses]
      filters << "talks_count:>0" unless options[:include_empty]

      search_options[:filter_by] = filters.join(" && ") if filters.any?

      sort_options = {
        "talks" => "talks_count:desc",
        "name" => "name:asc",
        "relevance" => "_text_match:desc,talks_count:desc"
      }

      search_options[:sort_by] = sort_options[options[:sort]] || sort_options["relevance"]

      search(query.presence || "*", query_by_fields, search_options)
    end
  end

  private

  def should_index?
    approved? && (talks_count || 0) > 0 && canonical_id.nil?
  end
end
