# frozen_string_literal: true

module Static
  class Event < Yerba::Record::Base
    include ActionView::Helpers::DateHelper
    include OwnedImports
    include LocationParsing

    self.path = "data/*parent_path/:series_id/:id/event.yml"

    schema EventSchema

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

        all.select { |event| event.end_date.is_a?(Date) && event.end_date >= import_cutoff }.each { |event| event.import!(index: index) }
      end

      def build(series_slug:)
        document = Yerba::Document.from({})
        record = new(document: document)

        record.series_id = series_slug
        record.parent_path = Static::EventSeries.find_by_slug(series_slug)&.parent_path

        record
      end

      def create(series_slug:, title:, id: nil, slug: nil, videos_file: true, **attributes)
        series = Static::EventSeries.find_by_slug(series_slug)
        raise ArgumentError, "Event series '#{series_slug}' not found" unless series

        slug ||= title.parameterize

        if id.present? && id != slug
          raise ArgumentError, "id must match the event folder name ('#{slug}'), got '#{id}'"
        end

        record = new(id: slug, title: title, **attributes.reject { |_, value| value.nil? || value == "" || value == [] })
        record.series_id = series_slug
        record.parent_path = series.parent_path
        record.save!(videos_file: videos_file)

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

    def ruby_focused?
      self["ruby_focused"] != false
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

    def old_ids
      Array(self["old_ids"]).compact_blank
    end

    def old_talk_ids
      Array(self["old_talk_ids"]).compact_blank
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

    def time_zone
      return nil if attributes["timezone"].blank?

      ActiveSupport::TimeZone[attributes["timezone"]]
    end

    def home_sort_date(event_record: nil)
      event_record ||= self.event_record

      if published_date
        return published_date
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
      migrate_old_talks!(event)
      import_sponsors!(event)
      import_involvements!(event)

      Search::Backend.index(event) if index

      event
    end

    def import_event!
      event = ::Event.find_by(slug: slug) || renamed_event_record || ::Event.new(slug: slug)

      event.assign_attributes(
        slug: slug,
        name: title,
        subtitle: self["subtitle"].to_s,
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
        ruby_focused: ruby_focused?,
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
      sync_old_slugs!(event)

      puts event.slug unless Rails.env.test?

      event
    rescue ActiveRecord::RecordInvalid => e
      error_location = ActiveSupport::BacktraceCleaner.new.clean_locations(e.backtrace_locations).first
      puts "::error file=#{error_location&.path},line=#{error_location&.lineno}::#{e.record.class} (#{e.record&.to_param}) - #{e.detailed_message}"
      raise e
    end

    def migrate_old_talks!(event)
      return if old_talk_ids.empty?

      old_talks = ::Talk.where(static_id: old_talk_ids)

      old_talks.where(meta_talk: true).or(old_talks.where(video_provider: "children")).find_each do |talk|
        if talk.child_talks.exists?
          puts "::warning::Talk #{talk.static_id} still has nested talks, so it doesn't redirect to #{event.slug} yet"
          next
        end

        ::Alias.where(aliasable: talk).find_each do |talk_alias|
          if ::Alias.where(slug: talk_alias.slug).where.not(id: talk_alias.id).exists? || ::Alias.exists?(aliasable_type: "Event", name: talk_alias.name)
            talk_alias.destroy!
          else
            talk_alias.update!(aliasable: event)
          end
        end

        if talk.slug.present? && talk.slug != event.slug && !::Alias.exists?(slug: talk.slug) && !::Alias.exists?(aliasable_type: "Event", name: talk.slug)
          event.slug_aliases.create!(name: talk.slug, slug: talk.slug)
        end

        if talk.video_provider.in?(::Talk::WATCHABLE_PROVIDERS)
          replacements = event.talks.where(video_provider: talk.video_provider, video_id: talk.video_id).where.not(id: talk.id).to_a

          talk.watched_talks.watched.find_each do |watched_talk|
            replacements.each do |cut_talk|
              cut_talk.watched_talks.find_or_create_by!(user_id: watched_talk.user_id) do |copy|
                copy.watched = true
                copy.watched_on = watched_talk.watched_on
                copy.watched_at = watched_talk.watched_at
                copy.feedback = watched_talk.read_attribute(:feedback)
                copy.feedback_shared_at = watched_talk.feedback_shared_at
              end
            end
          end
        else
          replacements = event.talks.watchable.where.not(id: talk.id).to_a

          talk.watched_talks.watched.includes(:user).find_each do |watched_talk|
            ::EventParticipation.record(user: watched_talk.user, event: event, role: "attendee")
          end
        end

        talk.watch_list_talks.includes(:watch_list).find_each do |entry|
          replacements.each { |replacement| entry.watch_list.watch_list_talks.find_or_create_by!(talk: replacement) }
        end

        talk.reload.destroy!
      end
    end

    def renamed_event_record
      old_ids.each do |old_id|
        event = ::Event.find_by(slug: old_id)
        return event if event
      end

      nil
    end

    def sync_old_slugs!(event)
      ::Event.where(slug: old_ids).where.not(id: event.id).find_each do |merged|
        next if merged.talks.exists?

        merged.event_participations.includes(:user).find_each do |participation|
          ::EventParticipation.record(user: participation.user, event: event, role: participation.role)
        end

        ::EventCheckIn.where(event: merged).find_each do |check_in|
          check_in.update!(event: event) unless ::EventCheckIn.exists?(connect_id: check_in.connect_id, event: event)
        end
        ::EventCheckIn.where(event: merged).delete_all

        merged.destroy!
      end

      old_ids.each do |old_id|
        next if ::Alias.exists?(slug: old_id)

        event.slug_aliases.create!(name: old_id, slug: old_id)
      end
    end

    def import_cfps!(event)
      import_cfps_into!(event, cfps)
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
      return unless sponsors.exist?

      import_sponsors_into!(event, sponsors)
    end

    def import_involvements!(event)
      return unless imported?
      return unless involvements.exist?

      import_involvements_into!(event, involvements)
    end

    def series_slug
      series_id
    end

    def event_dir
      File.dirname(file_path)
    end

    def persist_path
      return nil if series_slug.blank? || self["id"].blank?

      self.class.path_for({parent_path: parent_path, series_id: series_slug, id: self["id"]})
    end

    private def missing_parent_message(directory, to)
      relative_directory = Pathname.new(directory).relative_path_from(Pathname.new(path_root.to_s))

      %(The series "#{to[:series_id]}" doesn't exist yet (no #{relative_directory}/series.yml). ) +
        %(Create it first, for example in `bin/rails console` with `Static::EventSeries.create(name: "#{to[:series_id].titleize}", slug: "#{to[:series_id]}", kind: "#{kind}")`, ) +
        %(then move the event again.)
    end

    def save!(videos_file: true)
      self["id"] = self["title"]&.parameterize if new_record? && self["id"].blank?

      super()

      talks.ensure_file! if @was_new_record && videos_file
    end
  end
end
