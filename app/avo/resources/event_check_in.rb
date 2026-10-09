class Avo::Resources::EventCheckIn < Avo::BaseResource
  self.includes = [:event, {passport: :user}]
  self.search = {
    query: -> { query.where("connect_id LIKE ?", "%#{params[:q].upcase}%") }
  }

  def fields
    field :id, as: :id
    field :connect_id, as: :text, sortable: true
    field :event, as: :belongs_to, searchable: true
    field :passport, as: :belongs_to, name: "Passport", hide_on: :forms

    field :user, as: :text, as_html: true, name: "User", hide_on: :forms do
      user = record.user
      if user
        view_context.link_to(user.name, Avo::Engine.routes.url_helpers.resources_user_path(user))
      else
        view_context.content_tag(:span, "Unclaimed", class: "text-gray-400 italic")
      end
    end

    field :checked_in_at, as: :date_time, sortable: true
    field :created_at, as: :date_time, sortable: true
  end

  def actions
    action Avo::Actions::ImportEventCheckInStandalone
  end
end
