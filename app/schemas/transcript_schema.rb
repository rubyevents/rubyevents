# frozen_string_literal: true

class TranscriptSchema < RubyLLM::Schema
  string :video_id, description: "Video ID on the provider platform"
  array :cues, description: "Transcript cues" do
    object do
      string :start_time, description: "Start timestamp (HH:MM:SS.mmm)"
      string :end_time, description: "End timestamp (HH:MM:SS.mmm)"
      string :text, description: "Transcript text for this cue"
    end
  end
end
