class Avo::Resources::Alias < Avo::BaseResource
  self.includes = [:aliasable]
  self.search = {
    query: -> { query.where("name LIKE ? OR slug LIKE ?", "%#{params[:q]}%", "%#{params[:q]}%") }
  }
  self.external_link = -> {
    Avo::Resources::Alias.aliasable_link(main_app, record)
  }

  def filters
    filter Avo::Filters::AliasableType
  end

  def fields
    field :id, as: :id
    field :aliasable, as: :belongs_to, polymorphic_as: :aliasable, types: [::User, ::Event, ::EventSeries, ::Organization]
    field :name, as: :text, required: true
    field :slug, as: :text, required: true
    field :external_url,
      as: :text,
      hide_on: [:edit, :new],
      format_using: -> { view_context.link_to(value, value, target: "_blank") if value.present? } do

      Avo::Resources::Alias.aliasable_link(main_app, record)
    end
    field :created_at, as: :date_time, readonly: true
    field :updated_at, as: :date_time, readonly: true
  end

  def self.aliasable_link(app, record)
    case record.aliasable_type
    when "User"
      app.profile_path(record.slug)
    when "Event"
      app.event_path(record.slug)
    when "EventSeries"
      app.series_path(record.slug)
    when "Talk"
      app.talk_path(record.slug)
    when "Organization"
      app.organization_path(record.slug)
    else
      raise "Unknown aliasable type: #{record.aliasable_type}"
    end
  end
end
