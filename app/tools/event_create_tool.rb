# frozen_string_literal: true

class EventCreateTool < RubyLLM::Tool
  description "Create a new event within an event series. Creates the directory and event.yml file in the data/ folder."

  param :series_slug, desc: "Slug of the event series this event belongs to (e.g., 'rails-world', 'euruko')"
  param :slug, desc: "URL-friendly slug for the event (e.g., 'rails-world-2024'). Will be auto-generated from title if not provided.", required: false

  SCHEMA_DATA = EventSchema.new.to_json_schema[:schema].freeze

  SCHEMA_DATA[:properties].each do |name, config|
    required = SCHEMA_DATA[:required]&.include?(name)

    desc = config[:description] || ""
    desc += " (#{config[:enum].join(", ")})" if config[:enum]

    param name, desc: desc, required: required
  end

  def execute(**params)
    series_slug = params.delete(:series_slug)
    slug = params.delete(:slug)

    if params[:aliases].is_a?(String)
      params[:aliases] = params[:aliases].split(",").map(&:strip).reject(&:blank?)
    end

    event = Static::Event.create(series_slug: series_slug, slug: slug, **params)

    {
      success: true,
      slug: event.slug,
      title: event.title,
      series_slug: event.series_slug,
      data_path: "data/#{event.series_slug}/#{event.slug}/event.yml"
    }
  rescue ArgumentError => e
    {error: e.message}
  rescue => e
    {error: e.message}
  end
end
