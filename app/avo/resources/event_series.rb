class Avo::Resources::EventSeries < Avo::BaseResource
  self.single_includes = [:events]
  # self.search = {
  #   query: -> { query.ransack(id_eq: params[:q], m: "or").result(distinct: false) }
  # }
  self.find_record_method = -> {
    if id.is_a?(Array)
      query.where(slug: id)
    else
      query.find_by(slug: id)
    end
  }
  self.external_link = -> {
    main_app.series_path(record)
  }

  def fields
    field :id, as: :id
    field :name, as: :text, link_to_record: true
    field :description, as: :text, hide_on: [:index, :forms]
    field :website, as: :text
    field :language, as: :text
    field :kind, as: :select, enum: ::EventSeries.kinds
    field :frequency, as: :select, enum: ::EventSeries.frequencies, hide_on: :index
    field :youtube_channels, name: "YouTube Channels", as: :text, hide_on: [:index, :forms] do
      record.static_metadata&.all_youtube_channels&.map { |c| [c["name"], c["id"]].compact.join(" — ") }&.join(", ")
    end
    field :slug, as: :text, hide_on: :index
    field :twitter, as: :text, hide_on: :index
    # field :suggestions, as: :has_many
    field :events, as: :has_many
    field :talks, as: :has_many, through: :events
  end

  def filters
    filter Avo::Filters::Name
    filter Avo::Filters::Slug
  end
end
