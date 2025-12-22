# frozen_string_literal: true

class EventSchema < RubyLLM::Schema
  string :id, description: "Unique identifier for the event (YouTube playlist ID or custom slug)"

  string :title, description: "Full name of the event (e.g., 'RailsConf 2024')"
  string :description, description: "Description of the event", required: false
  array :aliases, of: :string, description: "Alternative names for the event", required: false

  string :kind, description: "Type of event", enum: ["conference", "meetup", "retreat", "hackathon", "event", "workshop"], required: true
  boolean :hybrid, description: "Whether the event has both in-person and online attendance", required: false
  string :status,
    description: "Event status",
    enum: ["cancelled", "postponed", "scheduled"],
    required: false
  boolean :last_edition, description: "Whether this is the last edition of the event", required: false

  string :start_date, description: "Start date of the event (YYYY-MM-DD format)", required: false
  string :end_date, description: "End date of the event (YYYY-MM-DD format)", required: false
  string :published_at, description: "Date when videos were published (YYYY-MM-DD format)", required: false
  string :announced_on, description: "Date when the event was announced (YYYY-MM-DD format)", required: false
  integer :year, description: "Year of the event", required: false
  string :date_precision,
    description: "Precision of the date (when exact dates are unknown)",
    enum: ["year", "month", "day"],
    required: false
  string :frequency, description: "How often the event occurs (for recurring meetups)", required: false

  string :location, description: "Location in 'City, Country' format (e.g., 'Detroit, MI' or 'Tokyo, Japan')"
  string :venue, description: "Name of the venue", required: false

  string :channel_id, description: "YouTube channel ID (starts with UC...)", required: false
  string :playlist, description: "YouTube playlist/Vimeo showcase link", required: false

  string :website, description: "Official event website URL", required: false
  string :original_website, description: "Original/archived website URL", required: false
  string :twitter, description: "Twitter/X handle (without @)", required: false
  string :mastodon, description: "Full Mastodon profile URL", required: false
  string :github, description: "GitHub organization or repository URL", required: false
  string :meetup, description: "Meetup.com group URL", required: false
  string :luma, description: "Luma event URL", required: false
  string :youtube, description: "YouTube channel or video URL", required: false

  string :banner_background,
    description: "CSS background value for the banner (color or gradient)",
    required: false
  string :featured_background,
    description: "CSS background color for featured cards",
    required: false
  string :featured_color,
    description: "CSS text color for featured cards",
    required: false

  object :coordinates, description: "Geographic coordinates", required: false do
    number :latitude, description: "Latitude coordinate"
    number :longitude, description: "Longitude coordinate"
  end
end
