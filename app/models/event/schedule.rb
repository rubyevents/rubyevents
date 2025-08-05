class Event::Schedule < ActiveRecord::AssociatedObject
  def file_path
    event.data_folder.join("schedule.yml")
  end

  def exist?
    file_path.exist?
  end

  def file
    YAML.load_file(file_path)
  end

  def days
    file.fetch("days", [])
  end

  def tracks
    file.fetch("tracks", [])
  end

  def talk_offsets
    days.map { |day|
      grid = day.fetch("grid", [])

      grid.sum { |item| item.fetch("items", []).any? ? 0 : item["slots"] }
    }
  end
end
