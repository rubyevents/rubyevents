# frozen_string_literal: true

module Static
  class EventSeries < Yerba::Record::Base
    self.path = "data/:id/series.yml"

    schema do
      string :id, description: "Unique identifier for the event series, matches the series folder name"
      string :name, description: "Name of the event series (e.g., 'RailsConf')"
      string :description, description: "Description of the event series", required: false

      string :kind,
        description: "Type of event series",
        enum: ["conference", "meetup", "retreat", "hackathon", "event", "podcast", "online", "organisation", "workshop"],
        required: false
      string :frequency,
        description: "How often the event occurs",
        enum: ["yearly", "monthly", "weekly", "irregular", "biweekly", "biyearly", "quarterly"],
        required: false
      boolean :inactive, description: "Whether the event series is inactive", required: false

      string :default_country_code, description: "Default ISO country code (e.g., 'US', 'JP')", required: false

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
      string :luma, description: "Luma event URL", required: false
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

      array :aliases, of: :string, description: "Alternative names for the series", required: false
    end

    SEARCH_INDEX_ON_IMPORT_DEFAULT = ENV.fetch("SEARCH_INDEX_ON_IMPORT", "true") == "true"

    class << self
      def find_by_slug(slug)
        slug_index[slug]
      end

      def unload!
        super

        @slug_index = nil
      end

      private

      def slug_index
        @slug_index ||= all.index_by(&:slug)
      end

      public

      def import_all!(index: SEARCH_INDEX_ON_IMPORT_DEFAULT)
        all.each { |series| series.import!(index: index) }
      end

      def import_all_series!(index: SEARCH_INDEX_ON_IMPORT_DEFAULT)
        all.each { |series| series.import_series!(index: index) }
      end

      def create(name:, slug: nil, **attributes)
        super(id: slug || name.parameterize, name: name, **attributes)
      end

      def find_or_create_by(name:, **attributes)
        find_by_slug(attributes[:slug] || name.parameterize) || create(name: name, **attributes)
      end
    end

    def slug
      self["id"]
    end

    def event_series_record
      @event_series_record ||= ::EventSeries.find_by(slug: slug) || import_series!
    end

    def import_series!(index: SEARCH_INDEX_ON_IMPORT_DEFAULT)
      event_series = ::EventSeries.find_or_initialize_by(slug: slug)

      event_series.update!(
        name: name,
        website: website || "",
        twitter: twitter || "",
        kind: kind,
        frequency: frequency,
        slug: slug,
        language: language || ""
      )

      event_series.sync_aliases_from_list(aliases) if aliases.present?

      Search::Backend.index(event_series) if index

      event_series
    end

    def import!(index: SEARCH_INDEX_ON_IMPORT_DEFAULT)
      import_series!(index: index)
      events.each { |event| event.import!(index: index) }
      event_series_record
    end

    def all_youtube_channels
      @all_youtube_channels ||= Array(self["youtube_channels"] || [])
    end

    def all_youtube_channel_ids
      all_youtube_channels.map { |channel| channel["id"] }.compact
    end

    has_many :events, foreign_key: :series_slug
    has_files :images, "app/assets/images/events/:id"
    has_files :default_images, "app/assets/images/events/:id/default"

    def persist_path
      return nil if self["id"].blank?

      self.class.path_for({id: self["id"]})
    end
  end
end
