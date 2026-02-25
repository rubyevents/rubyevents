class Event::Schedule < ActiveRecord::AssociatedObject
  include YAMLFile

  yaml_file "schedule.yml"

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
