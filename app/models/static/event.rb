# frozen_string_literal: true

module Static
  class Event < Yerba::Record::Base
    include ActionView::Helpers::DateHelper

    self.path = "data/:series_id/:id/event.yml"

    schema do
      string :id, description: "Unique identifier for the event, matches the event folder name"

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

      string :pre_date, description: "Date of pre-conference activities (workshops, pre-party) held before start_date (YYYY-MM-DD format)", required: false
      string :start_date, description: "Start date of the event (YYYY-MM-DD format)", required: false
      string :end_date, description: "End date of the event (YYYY-MM-DD format)", required: false
      string :recordings_published_date, description: "Date when the event's recordings were published (YYYY-MM-DD format)", required: false
      string :announced_on, description: "Date when the event was announced (YYYY-MM-DD format)", required: false
      integer :year, description: "Year of the event", required: false
      string :date_precision,
        description: "Precision of the date (when exact dates are unknown)",
        enum: ["year", "month", "day"],
        required: false
      string :frequency, description: "How often the event occurs (for recurring meetups)", required: false

      string :location, description: "Location in 'City, Country' format (e.g., 'Detroit, MI' or 'Tokyo, Japan')"
      string :timezone, description: "IANA time zone identifier, e.g. America/New_York", enum: TZInfo::Timezone.all_identifiers
      string :venue, description: "Name of the venue", required: false

      array :youtube_channels, of: YouTubeChannelSchema, description: "YouTube channels associated with this event", required: false

      array :removed_talk_ids, of: :string, description: "Ids of talks that were intentionally removed from videos.yml, so the removal is not mistaken for an unrecorded rename", required: false
      string :playlist, description: "YouTube playlist/Vimeo showcase link", required: false

      string :website, description: "Official event website URL", required: false
      string :original_website, description: "Original/archived website URL", required: false
      string :twitter, description: "Twitter/X handle (without @)", required: false
      string :facebook, description: "Facebook Page URL", required: false
      string :instagram, description: "Instagram handle (without @)", required: false
      string :mastodon, description: "Full Mastodon profile URL", required: false
      string :github, description: "GitHub organization or repository URL", required: false
      string :meetup, description: "Meetup.com group URL", required: false
      string :luma, description: "Luma event URL", required: false
      string :tickets_url, description: "URL to purchase tickets (e.g., Tito, Eventbrite, Luma)", required: false

      string :banner_background,
        description: "CSS background value for the banner (color or gradient)",
        required: false
      string :featured_background,
        description: "CSS background color for featured cards",
        required: false
      string :featured_color,
        description: "CSS text color for featured cards",
        required: false

      any_of :coordinates, description: "Geographic coordinates (use 'coordinates: false' for online events)" do
        object do
          number :latitude, description: "Latitude coordinate"
          number :longitude, description: "Longitude coordinate"
        end

        boolean
      end
    end

    belongs_to :series, class_name: "Static::EventSeries"

    has_many :talks, class_name: "Static::Talk"
    has_many :cfps
    has_many :sponsors
    has_many :involvements
    has_many :stickers, class_name: "Static::Sticker"
    has_many :stamps, class_name: "Static::EventStamp"

    has_one :venue
    has_one :schedule

    has_files :images, "app/assets/images/events/:series_id/:id"
    has_files :thumbnails, "app/assets/images/thumbnails/:id", recursive: true

    has_file :avatar, "app/assets/images/events/:series_id/:id/avatar.webp"
    has_file :banner, "app/assets/images/events/:series_id/:id/banner.webp"
    has_file :card, "app/assets/images/events/:series_id/:id/card.webp"
    has_file :featured, "app/assets/images/events/:series_id/:id/featured.webp"
    has_file :poster, "app/assets/images/events/:series_id/:id/poster.webp"

    SEARCH_INDEX_ON_IMPORT_DEFAULT = ENV.fetch("SEARCH_INDEX_ON_IMPORT", "true") == "true"

    class << self
      def find_by_slug(slug)
        slug_index[slug]
      end

      def import_all!(index: SEARCH_INDEX_ON_IMPORT_DEFAULT)
        all.each { |event| event.import!(index: index) }
      end

      def import_meetups!(index: SEARCH_INDEX_ON_IMPORT_DEFAULT)
        all.select { |event| event.meetup? }.each { |event| event.import!(index: index) }
      end

      def import_recent!(index: SEARCH_INDEX_ON_IMPORT_DEFAULT)
        import_cutoff = 6.months.ago

        all.select { |event| event.end_date && event.end_date >= import_cutoff }.each { |event| event.import!(index: index) }
      end

      def build(series_slug:)
        document = Yerba::Document.from({})
        record = new(document: document)

        record.series_id = series_slug

        record
      end

      def create(series_slug:, title:, id: nil, slug: nil, **attributes)
        series = Static::EventSeries.find_by_slug(series_slug)
        raise ArgumentError, "Event series '#{series_slug}' not found" unless series

        slug ||= title.parameterize

        if id.present? && id != slug
          raise ArgumentError, "id must match the event folder name ('#{slug}'), got '#{id}'"
        end

        record = new(id: slug, title: title, **attributes.reject { |_, value| value.nil? || value == "" || value == [] })
        record.series_id = series_slug
        record.save!

        unload!

        record
      end

      def find_or_create_by(series_slug:, title:, **attributes)
        slug = attributes[:slug] || title.parameterize

        find_by_slug(slug) || create(series_slug: series_slug, title: title, **attributes)
      end

      def unload!
        super
        @slug_index = nil
      end

      private

      def slug_index
        @slug_index ||= all.index_by(&:slug)
      end
    end

    def featured?
      within_next_days? || today? || past?
    end

    def banner_background
      self["banner_background"].presence || series&.banner_background
    end

    def featured_background
      self["featured_background"].presence || series&.featured_background
    end

    def featured_color
      self["featured_color"].presence || series&.featured_color
    end

    def today?
      if start_date.present?
        return start_date.today?
      end

      if end_date.present?
        return end_date.today?
      end

      if event_record.present? && event_record.start_date
        return event_record.start_date.today?
      end

      if event_record.present? && event_record.end_date
        return event_record.end_date.today?
      end

      false
    end

    def within_next_days?
      period = 4.days

      if end_date.present?
        return ((end_date - period)..end_date).cover?(Date.today)
      end

      if start_date.present?
        return ((start_date - period)..start_date).cover?(Date.today)
      end

      if event_record.present? && event_record.start_date
        return ((event_record.start_date - period)..event_record.start_date).cover?(Date.today)
      end

      if event_record.present? && event_record.end_date
        return ((event_record.end_date - period)..event_record.end_date).cover?(Date.today)
      end

      false
    end

    def past?
      if end_date.present?
        end_date.past?
      elsif event_record.present? && event_record.end_date.present?
        event_record.end_date.past?
      else
        false
      end
    end

    def conference?
      kind == "conference"
    end

    def meetup?
      kind == "meetup"
    end

    def retreat?
      kind == "retreat"
    end

    def hackathon?
      kind == "hackathon"
    end

    def slug
      self["id"]
    end

    def imported?
      ::Event.exists?(slug: slug)
    end

    def event_record
      @event_record ||= ::Event.find_by(slug: slug) || import!
    end

    def start_date
      Date.parse(self["start_date"])
    rescue TypeError, Date::Error
      self["start_date"]
    end

    def end_date
      Date.parse(self["end_date"])
    rescue TypeError, Date::Error
      self["end_date"]
    end

    def published_date
      Date.parse(recordings_published_date)
    rescue TypeError, Date::Error
      nil
    end

    def country
      return nil if location.blank?

      Country.find(location.to_s.split(",").last&.strip)
    end

    def time_zone
      return nil if attributes["timezone"].blank?

      ActiveSupport::TimeZone[attributes["timezone"]]
    end

    def city
      return nil if location.blank?

      parts = location.to_s.split(",").map(&:strip)
      parts.first if parts.size >= 2
    end

    def state_code
      parsed_state_code || featured_city&.state_code.presence
    end

    def resolved_city
      featured_city&.name || city
    end

    def featured_city
      return @featured_city if defined?(@featured_city)

      @featured_city = find_featured_city
    end

    def find_featured_city
      return nil if city.blank?

      Static::City.find_by_name_or_alias(city, country_code: country&.alpha2)
    end

    def parsed_state_code
      return nil if location.blank? || country.blank?
      return nil unless State.supported_country?(country)

      parts = location.to_s.split(",").map(&:strip)
      return nil if parts.size < 3

      state = State.find(country: country, term: parts[-2])
      state&.code
    end

    def home_sort_date(event_record: nil)
      event_record ||= self.event_record

      if published_date
        return published_date
      end

      if meetup?
        return event_record.end_date if event_record.present?

        return Time.at(0)
      end

      if end_date.present?
        return end_date
      end

      if start_date.present?
        return start_date
      end

      if event_record.present?
        return event_record.start_date
      end

      Time.at(0)
    end

    def import!(index: SEARCH_INDEX_ON_IMPORT_DEFAULT)
      return if Rails.env.test? && !ENV["SEED_SMOKE_TEST"]

      event = import_event!

      import_cfps!(event)
      import_videos!(event, index: index)
      import_sponsors!(event)
      import_involvements!(event)

      Search::Backend.index(event) if index

      event
    end

    def import_event!
      event = ::Event.find_or_initialize_by(slug: slug)

      event.assign_attributes(
        name: title,
        date: attributes["date"],
        date_precision: attributes["date_precision"] || "day",
        series: series.event_series_record,
        website: website,
        country_code: country&.alpha2,
        city: resolved_city,
        state_code: state_code,
        location: location,
        start_date: start_date,
        end_date: end_date,
        kind: kind,
        featured_background: featured_background,
        featured_color: featured_color,
        banner_background: banner_background,
        recordings_published_date: published_date,
        home_sort_date: home_sort_date(event_record: event)
      )

      if (venue_record = venue)
        venue_coordinates = venue_record["coordinates"] || {}

        event.assign_attributes(
          latitude: venue_coordinates["latitude"],
          longitude: venue_coordinates["longitude"]
        )
      else
        event.assign_attributes(
          latitude: coordinates.is_a?(Hash) ? coordinates.dig("latitude") : nil,
          longitude: coordinates.is_a?(Hash) ? coordinates.dig("longitude") : nil
        )
      end

      event.save! if event.changed? || event.new_record?

      event.sync_aliases_from_list(aliases) if aliases.present?

      puts event.slug unless Rails.env.test?

      event
    rescue ActiveRecord::RecordInvalid => e
      error_location = ActiveSupport::BacktraceCleaner.new.clean_locations(e.backtrace_locations).first
      puts "::error file=#{error_location&.path},line=#{error_location&.lineno}::#{e.record.class} (#{e.record&.to_param}) - #{e.detailed_message}"
      raise e
    end

    def import_cfps!(event)
      cfps.each do |cfp_data|
        cfp = event.cfps.find_or_initialize_by(link: cfp_data["link"])

        cfp.assign_attributes(
          name: cfp_data["name"],
          open_date: cfp_data["open_date"],
          close_date: cfp_data["close_date"]
        )

        cfp.save! if cfp.changed? || cfp.new_record?
      end
    end

    def import_videos!(event, index: SEARCH_INDEX_ON_IMPORT_DEFAULT)
      return unless imported?
      return unless talks.exist?

      talks.import!(event: event, index: index)

      destroy_removed_talks!(event)
    rescue ActiveRecord::RecordInvalid => e
      puts "Couldn't save: #{talk_data["title"]} (#{talk_data["id"]}), error: #{e.message}"
      error_location = ActiveSupport::BacktraceCleaner.new.clean_locations(e.backtrace_locations).first
      puts "::error file=#{error_location&.path},line=#{error_location&.lineno}::#{e.record.class} (#{e.record&.to_param}) - #{e.detailed_message}"
    end

    def destroy_removed_talks!(event)
      ids = Array(attributes["removed_talk_ids"])
      return if ids.empty?

      event.talks.where(static_id: ids).find_each do |talk|
        puts "Removing talk #{talk.static_id}" unless Rails.env.test?

        talk.destroy!
      end
    end

    def import_sponsors!(event)
      return unless imported?
      sponsors_collection = sponsors
      return unless sponsors_collection.exist?

      require "public_suffix"

      sponsor_ids = []
      sponsors_collection.each do |sponsors_entry|
        sponsors_entry["tiers"].each do |tier|
          tier["sponsors"].each do |sponsor|
            organization = nil
            domain = nil

            if sponsor["website"].present?
              begin
                uri = URI.parse(sponsor["website"])
                host = uri.host || sponsor["website"]
                parsed = PublicSuffix.parse(host)
                domain = parsed.domain

                organization = ::Organization.find_by(domain: domain) if domain.present?
              rescue PublicSuffix::Error, URI::InvalidURIError
              end
            end

            organization ||= ::Organization.find_by_name_or_alias(sponsor["name"]) || ::Organization.find_by_slug_or_alias(sponsor["slug"]&.downcase)
            organization ||= ::Organization.find_or_initialize_by(name: sponsor["name"])

            # Names like "フィヨルドブートキャンプ" parameterize to "", so fall back to the sponsor's slug
            if organization.new_record? && sponsor["name"].to_s.parameterize.blank?
              organization.slug = sponsor["slug"].to_s.parameterize
            end

            organization.update(
              website: sponsor["website"],
              description: sponsor["description"],
              domain: domain
            )

            organization.add_logo_url(sponsor["logo_url"]) if sponsor["logo_url"].present?
            organization.logo_url = sponsor["logo_url"] if sponsor["logo_url"].present? && organization.logo_url.blank?

            # The organization could not be saved, so discard the pending website and logo_url changes
            # and fall back to the record already in the database. Whatever an admin set by hand in
            # production wins over what a sponsors.yml file happens to say.
            unless organization.persisted?
              organization = ::Organization.find_by_slug_or_alias(organization.slug) ||
                ::Organization.find_by_name_or_alias(organization.name) || organization
            end

            organization.save! if organization.changed? || organization.new_record?

            sponsor_record = event.sponsors.find_or_initialize_by(organization:, event:, tier: tier["name"].presence)
            sponsor_record.assign_attributes(badge: sponsor["badge"], level: tier["level"])
            sponsor_record.save! if sponsor_record.changed? || sponsor_record.new_record?

            sponsor_ids << sponsor_record.id
          end
        end
      end

      event.sponsors.where.not(id: sponsor_ids).destroy_all
    rescue ActiveRecord::RecordInvalid => e
      error_location = ActiveSupport::BacktraceCleaner.new.clean_locations(e.backtrace_locations).first
      puts "::error file=#{error_location&.path},line=#{error_location&.lineno}::#{e.record.class} (#{e.record&.to_param}) - #{e.detailed_message}"
      raise e
    end

    def import_involvements!(event)
      return unless imported?
      involvements_collection = involvements
      return unless involvements_collection.exist?

      event_involvements = event.event_involvements

      event_involvements_attributes = event_involvements.map { it.attributes.merge(_destroy: true) }

      involvements_collection.each do |involvement_data|
        role = involvement_data["name"]

        Array.wrap(involvement_data["users"]).each_with_index do |user_name, index|
          next if user_name.blank?

          user = ::User.find_by_name_or_alias(user_name)

          unless user
            puts "Creating user: #{user_name}" unless Rails.env.test?
            user = ::User.create!(name: user_name)
          end

          attributes_index = event_involvements_attributes.index do |attrs|
            attrs["role"] == role && attrs["involvementable_type"] == "User" &&
              attrs["involvementable_id"] == user.id
          end

          if attributes_index.present?
            event_involvements_attributes[attributes_index].update(position: index, _destroy: false)
          else
            event_involvements_attributes << {
              role: role,
              involvementable: user,
              position: index
            }
          end
        end

        user_count = involvement_data["users"]&.compact&.size || 0

        Array.wrap(involvement_data["organisations"]).each_with_index do |org_name, index|
          next if org_name.blank?

          organization = ::Organization.find_by_name_or_alias(org_name) || ::Organization.find_by_slug_or_alias(org_name.parameterize)

          unless organization
            puts "Creating organization: #{org_name}" unless Rails.env.test?
            organization = ::Organization.create!(name: org_name)
          end

          attributes_index = event_involvements_attributes.index do |attrs|
            attrs["role"] == role && attrs["involvementable_type"] == "Organization" &&
              attrs["involvementable_id"] == organization.id
          end

          if attributes_index.present?
            event_involvements_attributes[attributes_index].update(position: index + user_count, _destroy: false)
          else
            event_involvements_attributes << {
              role: role,
              involvementable: organization,
              position: index + user_count
            }
          end
        end
      end
      event.update!(event_involvements_attributes: event_involvements_attributes)
    end

    def series_slug
      series_id
    end

    def event_dir
      File.dirname(file_path)
    end

    def persist_path
      return nil if series_slug.blank? || self["id"].blank?

      self.class.path_for({series_id: series_slug, id: self["id"]})
    end

    private def missing_parent_message(directory, to)
      relative_directory = Pathname.new(directory).relative_path_from(Pathname.new(path_root.to_s))

      %(The series "#{to[:series_id]}" doesn't exist yet (no #{relative_directory}/series.yml). ) +
        %(Create it first, for example in `bin/rails console` with `Static::EventSeries.create(name: "#{to[:series_id].titleize}", slug: "#{to[:series_id]}")`, ) +
        %(then move the event again.)
    end

    def save!
      self["id"] = self["title"]&.parameterize if new_record? && self["id"].blank?

      super

      talks.ensure_file! if @was_new_record
    end
  end
end
