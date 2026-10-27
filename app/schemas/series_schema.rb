# frozen_string_literal: true

class SeriesSchema < ApplicationSchema
  data_file "**/series.yml"

  string :id, description: "Unique identifier for the event series, matches the series folder name"
  array :old_ids, of: :string, description: "Previous ids, kept so the production series is moved to the new id on the next seed and its old URLs keep working", required: false
  array :old_event_ids, of: :string, description: "Ids of events merged into this series, like a meetup group's event that held all its meetups. The next seed moves their records to the series and redirects their URLs", required: false
  array :removed_talk_ids, of: :string, description: "Ids of talks of merged events that were intentionally removed", required: false
  string :name, description: "Name of the event series (e.g., 'RailsConf')"
  string :meetup_name, description: "Name a meetup group's meetups go by in their titles, when it differs from its name (e.g., 'LRUG')", required: false
  string :description, description: "Description of the event series", required: false

  string :kind,
    description: "Type of event series",
    enum: ["conference", "meetup", "retreat", "hackathon", "event", "podcast", "online", "organisation", "workshop"],
    required: false
  string :frequency,
    description: "How often the event occurs",
    enum: ["yearly", "monthly", "weekly", "irregular", "biweekly", "biyearly", "quarterly"],
    required: false
  boolean :ended,
    description: "The series stopped for good. A meetup group without an upcoming meetup and none in 18 months counts as inactive anyway",
    required: false

  string :default_country_code, description: "Default ISO country code (e.g., 'US', 'JP')", required: false

  string :location, description: "Where a meetup group meets, in 'City, Country' format (e.g., 'London, UK'), or 'online'", required: false
  string :timezone, description: "IANA time zone identifier of a meetup group, e.g. Europe/London", enum: TZInfo::Timezone.all_identifiers, required: false

  any_of :coordinates, description: "Geographic coordinates of a meetup group (use 'coordinates: false' for online groups)", required: false do
    object do
      number :latitude, description: "Latitude coordinate"
      number :longitude, description: "Longitude coordinate"
    end

    boolean
  end

  string :language, description: "Primary language of the event", enum: Language.english_names, required: false

  string :website, description: "Official website URL", required: false
  string :original_website, description: "Original/archived website URL", required: false
  string :twitter, description: "Twitter/X handle (without @)", required: false
  string :facebook, description: "Facebook Page URL", required: false
  string :instagram, description: "Instagram handle (without @)", required: false
  string :mastodon, description: "Full Mastodon profile URL", required: false
  string :bsky, description: "Bluesky handle", required: false
  string :github, description: "GitHub organization or repository", required: false
  string :linkedin, description: "LinkedIn page URL", required: false
  string :meetup, description: "Meetup.com group URL", required: false
  string :luma, description: "Luma calendar URL", required: false
  string :kommunity, description: "Kommunity group URL", required: false
  string :guild, description: "Guild.host URL", required: false
  string :vimeo, description: "Vimeo channel URL", required: false

  string :banner_background,
    description: "CSS background value for the banner of events using the series default banner.webp (color or gradient)",
    required: false

  string :featured_background,
    description: "CSS background color for featured cards of events using the series default featured.webp",
    required: false

  string :featured_color,
    description: "CSS text color for featured cards of events using the series default featured.webp",
    required: false

  array :youtube_channels, of: YouTubeChannelSchema, description: "YouTube channels associated with this series", required: false
  string :playlist, description: "YouTube playlist/Vimeo showcase link", required: false
  array :feeds, of: FeedSourceSchema, description: "External feeds (iCal, RSS, social) for this series", required: false

  array :aliases, of: :string, description: "Alternative names for the series", required: false
end
