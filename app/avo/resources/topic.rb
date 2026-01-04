class Avo::Resources::Topic < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  self.search = {
    query: -> { query.where("name LIKE ?", "%#{params[:q]}%") }
  }
  self.find_record_method = -> {
    if id.is_a?(Array)
      query.where(slug: id)
    else
      query.find_by(slug: id)
    end
  }
  self.keep_filters_panel_open = true
  self.external_link = -> {
    main_app.topic_path(record)
  }

  def fields
    field :id, as: :id
    field :name, as: :text, link_to_record: true
    field :talks_count, as: :number, hide_on: :forms, sortable: true
    field :canonical, as: :belongs_to, use_resource: "Topic", hide_on: :index
    field :description, as: :markdown, hide_on: :index
    field :status, as: :status, loading_when: "pending", success_when: "approved", failed_when: "rejected", hide_on: :forms
    field :status, as: :select, enum: ::Topic.statuses, only_on: :forms
    field :gem_names, as: :text, hide_on: :forms do
      record.topic_gems.pluck(:gem_name).join(", ")
    end
    field :talks, as: :has_many
    field :topic_gems, as: :has_many
  end

  def actions
    action Avo::Actions::ApproveTopic
    action Avo::Actions::RejectTopic
    action Avo::Actions::AssignCanonicalTopic
  end

  def filters
    filter Avo::Filters::Name
    filter Avo::Filters::Published
    filter Avo::Filters::TopicTalks
  end
end
