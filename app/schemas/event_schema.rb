# frozen_string_literal: true

class EventSchema < ApplicationSchema
  data_file "**/event.yml"

  string :id, description: "Unique identifier for the event, matches the event folder name"
  array :old_ids, of: :string, description: "Previous ids, kept so the production event is moved to the new id on the next seed and its old URLs keep working", required: false
  array :old_talk_ids, of: :string, description: "Ids of talks this event replaces, like a meetup that was a talk with nested talks in its group's videos.yml. The next seed turns their URLs into redirects to this event", required: false

  string :title, description: "Full name of the event (e.g., 'RailsConf 2024')"
  string :subtitle, description: "The event's own name or theme next to its title, like a meetup's 'Pubnite' or 'Ruby Tuesday #12'", required: false
  string :description, description: "Description of the event", required: false
  array :aliases, of: :string, description: "Alternative names for the event", required: false

  string :kind, description: "Type of event", enum: ["conference", "meetup", "retreat", "hackathon", "event", "workshop"], required: true
  boolean :hybrid, description: "Whether the event has both in-person and online attendance", required: false
  string :status,
    description: "Event status",
    enum: ["cancelled", "postponed", "scheduled"],
    required: false
  boolean :last_edition, description: "Whether this is the last edition of the event", required: false
  boolean :ruby_focused,
    description: "Whether the event is about Ruby (default true). Set to false for an event like a general programming conference that only had a Ruby talk, so it stays out of the event listings",
    required: false

  string :pre_date, description: "Date of pre-conference activities (workshops, pre-party) held before start_date (YYYY-MM-DD format)", required: false, pattern: "^\\d{4}-\\d{2}-\\d{2}$"
  string :start_date, description: "Start date of the event (YYYY-MM-DD format)", required: false, pattern: "^\\d{4}-\\d{2}-\\d{2}$"
  string :end_date, description: "End date of the event (YYYY-MM-DD format)", required: false, pattern: "^\\d{4}-\\d{2}-\\d{2}$"
  string :start_time, description: "Start time of a one-day event, like a meetup (HH:MM, in the event's timezone)", required: false, pattern: "^\\d{2}:\\d{2}$"
  string :end_time, description: "End time of a one-day event, like a meetup (HH:MM, in the event's timezone)", required: false, pattern: "^\\d{2}:\\d{2}$"
  string :recordings_published_date, description: "Date when the event's recordings were published (YYYY-MM-DD format)", required: false, pattern: "^\\d{4}-\\d{2}-\\d{2}$"
  string :announced_on, description: "Date when the event was announced (YYYY-MM-DD format)", required: false, pattern: "^\\d{4}-\\d{2}-\\d{2}$"
  string :date_precision,
    description: "Precision of the date (when exact dates are unknown)",
    enum: ["year", "month", "day"],
    required: false

  string :location, description: "Location in 'City, Country' format with the country written out (e.g., 'Detroit, MI, United States' or 'Tokyo, Japan'), or 'online'"
  string :timezone, description: "IANA time zone identifier, e.g. America/New_York", enum: TZInfo::Timezone.all_identifiers

  array :youtube_channels, of: YouTubeChannelSchema, description: "YouTube channels associated with this event", required: false
  array :feeds, of: FeedSourceSchema, description: "External feeds (iCal, RSS, social) for this event", required: false
  array :additional_resources, of: AdditionalResourceSchema, description: "Resources about the event as a whole, like the slides or write-up of a meetup", required: false
  array :removed_talk_ids, of: :string, description: "Ids of talks that were intentionally removed from videos.yml, so the removal is not mistaken for an unrecorded rename", required: false
  string :playlist, description: "YouTube playlist/Vimeo showcase link", required: false

  string :website, description: "Official event website URL", required: false
  string :original_website, description: "Original/archived website URL", required: false
  string :twitter, description: "Twitter/X handle (without @)", required: false
  string :facebook, description: "Facebook Page URL", required: false
  string :instagram, description: "Instagram handle (without @)", required: false
  string :mastodon, description: "Full Mastodon profile URL", required: false
  string :github, description: "GitHub organization or repository URL", required: false
  string :meetup, description: "Meetup.com event URL (e.g., 'https://www.meetup.com/lrug/events/123456789/')", required: false
  string :luma, description: "Luma event URL", required: false
  string :kommunity, description: "Kommunity event URL", required: false
  string :tickets_url, description: "URL to purchase tickets (e.g., Tito, Eventbrite, Luma)", required: false

  string :banner_background, description: "CSS background value for the banner (color or gradient)", required: false
  string :featured_background, description: "CSS background color for featured cards", required: false
  string :featured_color, description: "CSS text color for featured cards", required: false

  any_of :coordinates, description: "Geographic coordinates (use 'coordinates: false' for online events)", required: false do
    object do
      number :latitude, description: "Latitude coordinate"
      number :longitude, description: "Longitude coordinate"
    end

    boolean
  end
end
