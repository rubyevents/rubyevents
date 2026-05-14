# frozen_string_literal: true

class SubVideoSchema < RubyLLM::Schema
  string :id, required: true
  string :title, required: false
  string :raw_title, required: false
  string :description, required: false
  string :kind, description: "Type of video (e.g., 'keynote', 'lightning')", required: false
  array :speakers, of: :string, required: false
  string :event_name, required: false
  string :date, required: false
  string :published_at, required: false
  string :announced_at, required: false
  string :video_provider, description: "Use 'parent' if there is one video", required: true
  string :video_id, required: true
  string :language, required: false
  string :track, required: false
  string :location, description: "Location within the venue", required: false
  string :start_cue, description: "Start time cue in video", required: false
  string :end_cue, description: "End time cue in video", required: false
  string :thumbnail_cue, description: "Thumbnail time cue", required: false
  string :slides_url, required: false
  array :additional_resources, of: AdditionalResourceSchema, required: false
  string :thumbnail_xs, required: false
  string :thumbnail_sm, required: false
  string :thumbnail_md, required: false
  string :thumbnail_lg, required: false
  string :thumbnail_xl, required: false
  string :thumbnail_classes, required: false
  array :alternative_recordings, of: AlternativeRecordingSchema, required: false

  conditional video_provider: "youtube" do
    requires :published_at
    validates :published_at, type: :string, not_value: "TODO", min_length: 1, pattern: "^\\d{4}-\\d{2}-\\d{2}"
  end
end
