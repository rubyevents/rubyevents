class Avo::Resources::Event < Avo::BaseResource
  self.includes = []
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
    main_app.event_path(record)
  }

  def fields
    field :id, as: :id
    field :name, as: :text, link_to_record: true, sortable: true
    field :date, as: :date, hide_on: :index
    field :date_precision, as: :select, options: ::Event.date_precisions, hide_on: :index
    field :start_date, as: :date, hide_on: :index
    field :end_date, as: :date, hide_on: :index
    field :location, as: :text, hide_on: :index
    field :city, as: :text, hide_on: :index
    field :state_code, as: :text, hide_on: :index
    field :country_code, as: :select, options: country_options, include_blank: true
    field :latitude, as: :number, hide_on: :index
    field :longitude, as: :number, hide_on: :index
    field :geocode_metadata, as: :code, hide_on: :index
    field :kind, hide_on: :index
    field :slug, as: :text
    field :updated_at, as: :date, sortable: true
    # field :suggestions, as: :has_many
    field :series, as: :belongs_to
    field :talks, as: :has_many
    field :speakers, as: :has_many, through: :talks, class_name: "User"
    field :participants, as: :has_many, through: :event_participations, class_name: "User"
    field :event_involvements, as: :has_many
    field :topics, as: :has_many
    field :sponsors, as: :has_many
  end

  def actions
    action Avo::Actions::AssignCanonicalEvent
    action Avo::Actions::GeocodeRecord
  end

  def filters
    filter Avo::Filters::Name
    filter Avo::Filters::WithoutTalks
    filter Avo::Filters::Canonical
    filter Avo::Filters::LocationPresence
    filter Avo::Filters::GeocodedPresence
  end

  def country_options
    Country.select_options
  end
end
