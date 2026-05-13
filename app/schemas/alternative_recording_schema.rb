# frozen_string_literal: true

class AlternativeRecordingSchema < RubyLLM::Schema
  string :title, required: false
  string :raw_title, required: false
  string :language, required: false
  string :date, required: false
  string :description, required: false
  string :published_at, required: false
  string :event_name, required: false
  array :speakers, of: :string, required: false
  string :video_provider, required: false
  string :video_id, required: false
  string :url, required: false
  string :external_url, required: false
end
