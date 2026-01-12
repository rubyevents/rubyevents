class Avo::Resources::Talk < Avo::BaseResource
  self.includes = [:event, :speakers, :topics]
  self.find_record_method = -> {
    if id.is_a?(Array)
      query.where(slug: id)
    else
      query.find_by(slug: id)
    end
  }
  self.keep_filters_panel_open = true

  self.search = {
    query: -> { query.where(id: Talk.search(params[:q]).map(&:id)) }
  }
  self.external_link = -> {
    main_app.talk_path(record)
  }

  def fields
    field :id, as: :id
    field :title, as: :text, link_to_record: true, sortable: true
    field :event, as: :belongs_to

    field :speaker_tags, for_attribute: :speakers, name: "Speakers", through: :speaker_talks, as: :tags, hide_on: [:show, :forms] do
      record.speakers.map(&:name)
    end

    field :topics, as: :tags, hide_on: [:index, :forms] do
      record.topics.map(&:name)
    end
    field :updated_at, as: :date, sortable: true
    field :slides_url, as: :text, hide_on: :index
    field :summary, as: :easy_mde, hide_on: :index
    field :has_raw_transcript, name: "Raw Transcript", as: :boolean do
      record.raw_transcript.present?
    end
    field :has_enhanced_transcript, hide_on: :index, name: "Enhanced Transcript", as: :boolean do
      record.enhanced_transcript.present?
    end
    field :raw_transcript_length, name: "Raw Transcript length", as: :number do
      record.raw_transcript&.to_text&.length
    end
    field :enhanced_transcript_length, name: "Enhanced Transcript length", as: :number do
      record.enhanced_transcript&.to_text&.length
    end
    field :has_duration, name: "Duration", as: :boolean do
      record.duration_in_seconds.present?
    end
    field :has_summary, name: "Summary", as: :boolean do
      record.summary.present?
    end
    field :has_topics, name: "Topics", as: :boolean do
      record.topics.any?
    end
    field :language, hide_on: :index
    field :slug, as: :text, hide_on: :index
    field :year, as: :number, hide_on: :index
    field :video_id, as: :text, hide_on: :index
    field :video_provider, as: :text, hide_on: :index
    field :external_player, as: :boolean, hide_on: :index
    field :date, as: :date, hide_on: :index
    field :like_count, as: :number, hide_on: :index
    field :view_count, as: :number, hide_on: :index
    field :duration_in_seconds, as: :number, hide_on: [:index, :edit], format_using: -> { Duration.seconds_to_formatted_duration(value, raise: false) }, name: "Duration", readonly: true
    field :duration_in_seconds, as: :number, hide_on: :index, show_on: [:edit], name: "Duration in seconds"
    field :created_at, as: :date, hide_on: :index
    field :updated_at, as: :date, sortable: true, filterable: true
    field :description, as: :textarea, hide_on: :index

    field :thumbnail_xs, as: :external_image, hide_on: :index
    field :thumbnail_sm, as: :external_image, hide_on: :index
    field :thumbnail_md, as: :external_image, hide_on: :index
    field :thumbnail_lg, as: :external_image, hide_on: :index
    field :thumbnail_xl, as: :external_image, hide_on: :index
    # field :speaker_talks, as: :has_many, attach_scope: -> { query.order(name: :asc) }
    field :speakers, as: :has_many
    field :raw_transcript, as: :textarea, hide_on: :index, format_using: -> { value&.to_text }, readonly: true
    field :enhanced_transcript, as: :textarea, hide_on: :index, format_using: -> { value&.to_text }, readonly: true
    # field :suggestions, as: :has_many
  end

  def actions
    action Avo::Actions::TalkIngest
    action Avo::Actions::UpdateFromYml
    action Avo::Actions::TalkIndex
    action Avo::Actions::FetchDuration
  end

  def filters
    filter Avo::Filters::TalkEvent
    filter Avo::Filters::RawTranscript
    filter Avo::Filters::EnhancedTranscript
    filter Avo::Filters::Summary
    filter Avo::Filters::Topics
    filter Avo::Filters::Title
    filter Avo::Filters::Slug
    filter Avo::Filters::Language
    filter Avo::Filters::VideoProvider
  end
end
