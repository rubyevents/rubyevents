class Avo::Resources::City < Avo::BaseResource
  self.model_class = ::City
  self.title = :name
  self.includes = []
  self.find_record_method = -> {
    if id.is_a?(Array)
      query.where(slug: id)
    else
      query.find_by(slug: id)
    end
  }
  self.search = {
    query: -> { query.where("name LIKE ?", "%#{params[:q]}%") }
  }
  self.external_link = -> {
    main_app.city_path(record)
  }
  self.map_view = {
    mapkick_options: {
      controls: true
    },
    record_marker: -> {
      {
        latitude: record.latitude,
        longitude: record.longitude,
        tooltip: record.name
      }
    },
    table: {
      visible: true
    }
  }

  def fields
    field :id, as: :id
    field :name, as: :text, link_to_record: true, sortable: true
    field :slug, as: :text, sortable: true
    field :state_code, as: :text
    field :country_code, as: :select, options: country_options, include_blank: true
    field :featured, as: :boolean, sortable: true
    field :latitude, as: :number, hide_on: :index
    field :longitude, as: :number, hide_on: :index
    field :geocode_metadata, as: :code, language: :json, hide_on: :index
    field :created_at, as: :date_time, hide_on: :forms, sortable: true
    field :updated_at, as: :date_time, hide_on: :forms, sortable: true
  end

  def filters
    filter Avo::Filters::Name
  end

  def country_options
    Country.select_options
  end
end
