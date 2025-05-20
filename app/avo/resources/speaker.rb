class Avo::Resources::Speaker < Avo::BaseResource
  self.includes = []
  self.find_record_method = -> {
    if id.is_a?(Array)
      query.where(slug: id)
    else
      query.find_by(slug: id) || query.find_by(id:)
    end
  }
  self.search = {
    query: -> { query.where("lower(name) LIKE ?", "%#{params[:q].downcase}%") }
  }
  self.external_link = -> {
    main_app.speaker_path(record)
  }

  def fields
    field :id, as: :id, link_to_record: true
    field :name, as: :text, link_to_record: true, sortable: true
    field :github, as: :text
    field :bio, as: :textarea, hide_on: :index
    field :slug, as: :text, hide_on: :index
    field :talks_count, as: :number, sortable: true
    field :canonical, as: :belongs_to, hide_on: :index
    # field :suggestions, as: :has_many
    field :speaker_talks, as: :has_many, resource: Avo::Resources::SpeakerTalk, attach_scope: -> { query.order(title: :asc) }
    # field :speaker_talks, as: :has_many
    field :social_profiles, as: :has_many, use_resource: "Avo::Resources::SocialProfile"
    field :talks, as: :has_many, use_resource: "Avo::Resources::Talk", attach_scope: -> { query.order(title: :asc) }, searchable: true
  end

  def filters
    filter Avo::Filters::Name
    filter Avo::Filters::Slug
    filter Avo::Filters::GitHub
    filter Avo::Filters::GitHubHandle
  end

  def actions
    action Avo::Actions::SpeakerGitHub
    action Avo::Actions::AssignCanonicalSpeaker
  end
end
