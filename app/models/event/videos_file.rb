# -*- SkipSchemaAnnotations

class Event::VideosFile < ActiveRecord::AssociatedObject
  FILE_NAME = "videos.yml"

  def file_path
    event.data_folder.join(FILE_NAME)
  end

  def exist?
    file_path.exist?
  end

  def entries
    return [] unless exist?

    YAML.load_file(file_path) || []
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
