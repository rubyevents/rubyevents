# frozen_string_literal: true

class ScheduleSchema < RubyLLM::Schema
  array :days, description: "List of conference days" do
    object do
      string :name, description: "Name of the day (e.g., 'Day 1', 'Workshop Day')"
      string :date, description: "Date of the day (YYYY-MM-DD format)"

      array :grid, description: "Time slots for the day", required: false do
        object do
          string :start_time, description: "Start time (HH:MM format)"
          string :end_time, description: "End time (HH:MM format)"
          integer :slots, description: "Number of parallel tracks/slots", required: false
          string :description, description: "Description of the time slot", required: false

          array :items, description: "Items in this time slot", required: false do
            any_of do
              string description: "Simple item name (e.g., 'Lunch', 'Break')"

              object do
                string :title, description: "Title of the session"
                string :description, description: "Description of the session", required: false
                array :speakers, of: :string, description: "List of speaker names", required: false
                string :track, description: "Track name", required: false
                string :room, description: "Room name/number", required: false
              end
            end
          end
        end
      end
    end
  end

  array :tracks, description: "Track definitions for the schedule", required: false do
    object do
      string :name, description: "Track name"
      string :color, description: "Track color (hex)", required: false
      string :text_color, description: "Text color for the track (hex)", required: false
    end
  end
end
