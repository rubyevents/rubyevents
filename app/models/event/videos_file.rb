# -*- SkipSchemaAnnotations

class Event::VideosFile < ActiveRecord::AssociatedObject
  include YAMLFile

  yaml_file "videos.yml"

  extension do
    def talks_in_running_order(child_talks: true)
      talks.in_order_of(:static_id, videos_file.ids(child_talks: child_talks))
    end
  end

  def ids(child_talks: true)
    return [] unless exist?

    if child_talks
      entries.flat_map { |talk|
        [talk.dig("id"), *talk["talks"]&.map { |child_talk|
          child_talk.dig("id")
        }]
      }
    else
      entries.map { |talk| talk.dig("id") }
    end
  end

  def find_by_id(id)
    entries.find { |talk| talk["id"] == id }
  end

  def count
    entries.size
  end
end
