class Avo::Resources::TalkTranscript < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  self.model_class = ::Talk::Transcript
  # self.search = {
  #   query: -> { query.ransack(id_eq: params[:q], m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :talk, as: :belongs_to
    field :raw_transcript, as: :textarea, hide_on: [:index]
    field :enhanced_transcript, as: :textarea, hide_on: [:index]
    field :created_at, as: :date_time, sortable: true, hide_on: [:index]
    field :updated_at, as: :date_time, sortable: true
  end

  def actions
    action Avo::Actions::EnhanceTranscript
  end
end
