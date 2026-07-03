# -*- SkipSchemaAnnotations

class Event::TranscriptsFile < ActiveRecord::AssociatedObject
  include YAMLFile

  yaml_file "transcripts.yml"

  def video_ids
    entries.map { |entry| entry["video_id"] }.compact
  end

  def find_by_video_id(video_id)
    entries.find { |entry| entry["video_id"] == video_id }
  end

  def cues_for_video(video_id)
    entry = find_by_video_id(video_id)
    return [] unless entry

    Array.wrap(entry["cues"])
  end
end
