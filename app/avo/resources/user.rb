class Avo::Resources::User < Avo::BaseResource
  self.title = :name
  self.includes = []
  self.find_record_method = -> {
    if id.is_a?(Array)
      (id.first.to_i == 0) ? query.where(slug: id) : query.where(id: id)
    else
      (id.to_i == 0) ? (query.find_by_slug_or_alias(id) || query.find_by_github_handle(id)) : query.find(id)
    end
  }
  self.search = {
    query: -> { query.where("lower(name) LIKE ? OR email LIKE ?", "%#{params[:q]&.downcase}%", "%#{params[:q]}%") }
  }
  self.external_link = -> {
    main_app.profile_path(record)
  }

  def fields
    field :id, as: :id, link_to_record: true
    field :name, as: :text, link_to_record: true
    field :email, as: :text, link_to_record: true, format_using: -> { value&.truncate(30) }, only_on: :index
    field :email, as: :text, link_to_record: true, hide_on: :index
    field :github_handle, as: :text, link_to_record: true
    field :admin, as: :boolean
    field :marked_for_deletion, as: :boolean, hide_on: :index

    field :slug, as: :text, hide_on: :index
    field :bio, as: :textarea, hide_on: :index
    field :website, as: :text, hide_on: :index
    field :twitter, as: :text, hide_on: :index
    field :bsky, as: :text, hide_on: :index
    field :linkedin, as: :text, hide_on: :index
    field :mastodon, as: :text, hide_on: :index
    field :speakerdeck, as: :text, hide_on: :index
    field :pronouns, as: :text, hide_on: :index
    field :pronouns_type, as: :text, hide_on: :index
    field :talks_count, as: :number, sortable: true
    field :canonical, as: :belongs_to, hide_on: [:index, :forms], searchable: true

    field :aliases, as: :has_many, hide_on: :index
    field :talks, as: :has_many, hide_on: :index
    field :user_talks, as: :has_many, hide_on: :index
    field :connected_accounts, as: :has_many
    field :sessions, as: :has_many
    field :event_participations, as: :has_many, hide_on: :index, use_resource: Avo::Resources::EventParticipation
    field :participated_events, as: :has_many, hide_on: :index, use_resource: Avo::Resources::Event
    field :event_involvements, as: :has_many, hide_on: :index
  end

  def filters
    filter Avo::Filters::Name
    filter Avo::Filters::Slug
    filter Avo::Filters::GitHubHandle
    filter Avo::Filters::GitHubHandlePresence
    filter Avo::Filters::BioPresence
  end

  def actions
    action Avo::Actions::AssignCanonicalUser
    action Avo::Actions::UserFetchGitHub
  end
end
