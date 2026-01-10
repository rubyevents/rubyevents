# frozen_string_literal: true

module Organization::TypesenseSearchable
  extend ActiveSupport::Concern

  included do
    include ::Typesense

    typesense enqueue: :trigger_typesense_job, if: :should_index? do
      attributes :name, :slug, :description, :website, :main_location

      attribute :kind

      attribute :events_count do
        events.distinct.count
      end

      attribute :sponsorships_count do
        sponsors.count
      end

      attribute :avatar_path do
        avatar_image_path
      end

      attribute :has_logo do
        has_logo_image?
      end

      predefined_fields [
        {"name" => "name", "type" => "string"},
        {"name" => "description", "type" => "string", "optional" => true},
        {"name" => "slug", "type" => "string"},

        {"name" => "kind", "type" => "string", "facet" => true},
        {"name" => "website", "type" => "string", "optional" => true},
        {"name" => "main_location", "type" => "string", "optional" => true, "facet" => true},

        {"name" => "events_count", "type" => "int32"},
        {"name" => "sponsorships_count", "type" => "int32"},

        {"name" => "avatar_path", "type" => "string", "optional" => true},
        {"name" => "has_logo", "type" => "bool"}
      ]

      default_sorting_field "events_count"

      token_separators %w[- _]
    end
  end

  class_methods do
    def trigger_typesense_job(record, remove)
      TypesenseIndexJob.perform_later(record, remove ? "typesense_remove_from_index!" : "typesense_index!")
    end

    def typesense_search_organizations(query, options = {})
      query_by_fields = "name,description"

      search_options = {
        query_by_weights: "10,3",
        per_page: options[:per_page] || 20,
        page: options[:page] || 1,
        highlight_full_fields: "name",
        highlight_affix_num_tokens: 10
      }

      filters = []
      filters << "kind:=#{options[:kind]}" if options[:kind].present?
      filters << "events_count:>0" unless options[:include_without_events]

      search_options[:filter_by] = filters.join(" && ") if filters.any?

      sort_options = {
        "events" => "events_count:desc",
        "sponsorships" => "sponsorships_count:desc",
        "name" => "name:asc",
        "relevance" => "_text_match:desc,events_count:desc"
      }

      search_options[:sort_by] = sort_options[options[:sort]] || sort_options["relevance"]

      search(query.presence || "*", query_by_fields, search_options)
    end
  end

  private

  def should_index?
    events.any? || sponsors.any?
  end
end
