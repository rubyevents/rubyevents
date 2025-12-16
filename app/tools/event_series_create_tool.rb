# frozen_string_literal: true

class EventSeriesCreateTool < RubyLLM::Tool
  description "Create a new event series (conference, meetup, etc.). Creates the directory and series.yml file in the data/ folder."

  param :slug, desc: "URL-friendly slug for the series (e.g., 'railsconf', 'ruby-meetup-nyc'). Will be used as directory name.", required: false

  SCHEMA_DATA = SeriesSchema.new.to_json_schema[:schema].freeze

  SCHEMA_DATA[:properties].each do |name, config|
    required = SCHEMA_DATA[:required]&.include?(name)

    desc = config[:description] || ""
    desc += " (#{config[:enum].join(", ")})" if config[:enum]

    param name, desc: desc, required: required
  end

  def execute(**params)
    slug = params.delete(:slug)

    if params[:aliases].is_a?(String)
      params[:aliases] = params[:aliases].split(",").map(&:strip).reject(&:blank?)
    end

    series = Static::EventSeries.create(slug: slug, **params)

    {
      success: true,
      slug: series.slug,
      name: series.name,
      data_path: series.__file_path
    }
  rescue ArgumentError => e
    {error: e.message}
  rescue => e
    {error: e.message}
  end
end
