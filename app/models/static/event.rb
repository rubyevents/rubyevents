# frozen_string_literal: true

module Static
  class Event < Yerba::Record::Base
    include ActionView::Helpers::DateHelper

    self.glob = "**/event.yml"
    self.base_path = Rails.root.join("data")

    schema EventSchema

    belongs_to :series, class_name: "Static::EventSeries", foreign_key: :series_slug

    has_many :talks, in_file: "videos.yml", class_name: "Static::Talk"
    has_many :videos, in_file: "videos.yml", class_name: "Static::Talk" # TODO: remove, use :talks instead
    has_many :cfps, in_file: "cfp.yml"
    has_many :sponsors, in_file: "sponsors.yml"
    has_many :involvements, in_file: "involvements.yml"

    has_one :venue, in_file: "venue.yml"
    has_one :schedule, in_file: "schedule.yml"

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
        document = Yerba::Record::Document.from({})
        record = new(document: document)

        record.instance_variable_set(:@series_slug_override, series_slug)

        record
      end

      def find_or_create_by(series_slug:, title:, **attributes)
        slug = attributes[:slug] || title.parameterize

        find_by_slug(slug) || create(series_slug: series_slug, title: title, **attributes)
      end

      public

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
      @slug ||= self["slug"].presence || File.basename(File.dirname(file_path))
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
      Date.parse(published_at)
    rescue TypeError, Date::Error
      nil
    end

    def country
      return nil if location.blank?

      Country.find(location.to_s.split(",").last&.strip)
    end

    def city
      return nil if location.blank?

      parts = location.to_s.split(",").map(&:strip)
      parts.first if parts.size >= 2
    end

    def home_sort_date(event_record: nil)
      event_record ||= self.event_record

      if published_date
        return published_date
      end

      if conference? && end_date.present?
        return end_date
      end

      if meetup? && event_record.present?
        return event_record.end_date
      end

      if conference? && start_date.present?
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
      import_transcripts!(event)

      Search::Backend.index(event) if index

      event
    end

    def import_event!
      event = ::Event.find_or_initialize_by(slug: slug)

      event.assign_attributes(
        name: title,
        date: self["date"] || published_at,
        date_precision: date_precision || "day",
        series: series.event_series_record,
        website: website,
        country_code: country&.alpha2,
        city: city,
        location: location,
        start_date: start_date,
        end_date: end_date,
        kind: kind,
        featured_background: featured_background,
        featured_color: featured_color,
        banner_background: banner_background,
        home_sort_date: home_sort_date(event_record: event)
      )

      if event.venue.exist?
        event.assign_attributes(
          latitude: event.venue.latitude,
          longitude: event.venue.longitude
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
      cfp_file_path = Rails.root.join("data", series_slug, slug, "cfp.yml")

      return unless File.exist?(cfp_file_path)

      cfps = YAML.load_file(cfp_file_path)

      cfps.each do |cfp_data|
        cfp = event.cfps.find_or_initialize_by(
          link: cfp_data["link"],
          open_date: cfp_data["open_date"]
        )
        cfp.assign_attributes(
          name: cfp_data["name"],
          close_date: cfp_data["close_date"]
        )

        cfp.save! if cfp.changed? || cfp.new_record?
      end
    end

    def import_videos!(event, index: SEARCH_INDEX_ON_IMPORT_DEFAULT)
      return unless imported?
      return unless event.videos_file.exist?

      Static::Video.where_event_slug(slug).each do |video|
        video.import!(event: event, index: index)
      end
    rescue ActiveRecord::RecordInvalid => e
      puts "Couldn't save: #{talk_data["title"]} (#{talk_data["id"]}), error: #{e.message}"
      error_location = ActiveSupport::BacktraceCleaner.new.clean_locations(e.backtrace_locations).first
      puts "::error file=#{error_location&.path},line=#{error_location&.lineno}::#{e.record.class} (#{e.record&.to_param}) - #{e.detailed_message}"
    end

    def import_sponsors!(event)
      return unless imported?
      return unless event.sponsors_file.exist?

      require "public_suffix"

      organisation_ids = []
      event.sponsors_file.file.each do |sponsors|
        sponsors["tiers"].each do |tier|
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

            organization.update(
              website: sponsor["website"],
              description: sponsor["description"],
              domain: domain
            )

            organization.add_logo_url(sponsor["logo_url"]) if sponsor["logo_url"].present?
            organization.logo_url = sponsor["logo_url"] if sponsor["logo_url"].present? && organization.logo_url.blank?

            organization = ::Organization.find_by_slug_or_alias(organization.slug) || ::Organization.find_by_name_or_alias(organization.name) unless organization.persisted?

            organization.save! if organization.changed? || organization.new_record?

            organisation_ids << organization.id

            sponsor_record = event.sponsors.find_or_initialize_by(organization:, event:)
            sponsor_record.assign_attributes(tier: tier["name"], badge: sponsor["badge"], level: tier["level"])
            sponsor_record.save! if sponsor_record.changed? || sponsor_record.new_record?
          end
        end
      end

      event.sponsors.where.not(organization_id: organisation_ids).destroy_all
    rescue ActiveRecord::RecordInvalid => e
      error_location = ActiveSupport::BacktraceCleaner.new.clean_locations(e.backtrace_locations).first
      puts "::error file=#{error_location&.path},line=#{error_location&.lineno}::#{e.record.class} (#{e.record&.to_param}) - #{e.detailed_message}"
      raise e
    end

    def import_involvements!(event)
      return unless imported?
      return unless event.involvements_file.exist?

      event_involvements = event.event_involvements

      event_involvements_attributes = event_involvements.map { it.attributes.merge(_destroy: true) }

      involvements = event.involvements_file.entries

      involvements.each do |involvement_data|
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

    def import_transcripts!(event)
      return unless imported?
      return unless event.transcripts_file.exist?

      transcripts = event.transcripts_file.entries
      return if transcripts.blank?

      transcripts.each do |transcript_data|
        video_id = transcript_data["video_id"]
        cues = transcript_data["cues"]

        next if video_id.blank? || cues.blank?

        talk = event.talks.find_by(video_id: video_id)
        next unless talk

        transcript = ::Transcript.new
        cues.each do |cue_data|
          transcript.add_cue(
            Cue.new(
              start_time: cue_data["start_time"],
              end_time: cue_data["end_time"],
              text: cue_data["text"]
            )
          )
        end

        transcript_record = talk.talk_transcript || ::Talk::Transcript.new(talk: talk)
        transcript_record.update_attributes(raw_transcript: transcript)
        transcript_record.save! if transcript_record.changed? || transcript_record.new_record?
      end
    end

    def series_slug
      @series_slug ||= relative_file_path.split("/")[-3]
    end

    def event_dir
      File.dirname(file_path)
    end

    def persist_path
      series = @series_slug_override || self["series_slug"] || series_slug
      event = self["slug"] || self["title"]&.parameterize

      return nil unless series && event

      File.join(self.class.base_path, series, event, "event.yml")
    end

    def save!
      super

      if @was_new_record
        videos_path = File.join(File.dirname(file_path), "videos.yml")

        Yerba::Document.from([]).save_to!(videos_path) unless File.exist?(videos_path)
      end
    end
  end
end
