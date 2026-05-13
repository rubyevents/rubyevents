# frozen_string_literal: true

class VideoSchema < RubyLLM::Schema
  string :id, description: "Unique identifier for the video", required: true
  string :title, description: "Title of the talk"
  string :raw_title, description: "Original/raw title from the video source", required: false
  string :original_title, description: "Original title in native language", required: false
  string :description, description: "Description of the talk"
  string :slug, description: "URL-friendly slug", required: false
  string :kind, description: "Type of video (e.g., 'keynote', 'lightning')", required: false
  string :status, description: "Status of the video", required: false

  array :speakers, of: :string, description: "List of speaker names", required: false
  array :talks, of: SubVideoSchema, description: "Sub-talks for panel discussions", required: false

  string :event_name, description: "Name of the event (e.g., 'RailsConf 2024')", required: false
  string :date, description: "Date of the talk (YYYY-MM-DD format)", required: true
  string :time, description: "Time of the talk", required: false
  string :published_at, description: "Date when the video was published (YYYY-MM-DD format)", required: false
  string :announced_at, description: "Date when the talk was announced", required: false
  string :location, description: "Location within the venue", required: false

  string :video_provider,
    description: "Video hosting provider",
    enum: ["youtube", "vimeo", "not_recorded", "scheduled", "mp4", "parent", "children", "not_published"]
  string :video_id, description: "Video ID on the provider platform"

  boolean :external_player, description: "Whether to use external player", required: false
  string :external_player_url, description: "URL for external player", required: false
  string :track, description: "Conference track (e.g., 'Main Stage', 'Workshop')", required: false
  string :language, description: "Language of the talk", required: false
  string :slides_url, description: "URL to the slides", required: false

  array :alternative_recordings, of: AlternativeRecordingSchema, description: "Alternative video recordings", required: false
  array :additional_resources, of: AdditionalResourceSchema, description: "Additional resources related to the talk", required: false

  string :thumbnail_xs, description: "Extra small thumbnail URL", required: false
  string :thumbnail_sm, description: "Small thumbnail URL", required: false
  string :thumbnail_md, description: "Medium thumbnail URL", required: false
  string :thumbnail_lg, description: "Large thumbnail URL", required: false
  string :thumbnail_xl, description: "Extra large thumbnail URL", required: false
  string :thumbnail_classes, description: "CSS classes for thumbnail", required: false

  require_if :video_provider, equals: "youtube" do
    requires :published_at
    validates :published_at, not_value: "TODO", min_length: 1, pattern: "^\\d{4}-\\d{2}-\\d{2}"
  end
end
