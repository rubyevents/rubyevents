# frozen_string_literal: true

module Static
  class EventSeries < Yerba::Record::Base
    self.path = "data/*parent_path/:id/series.yml"

    schema SeriesSchema

    include OwnedImports
    include LocationParsing

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

      def create(name:, slug: nil, parent: nil, **attributes)
        record = new(id: slug || name.parameterize, name: name, **attributes.reject { |_, value| value.nil? || value == "" || value == [] })
        record.parent_path = parent.directory if parent
        record.save!

        unload!

        record
      end

      def find_or_create_by(name:, **attributes)
        find_by_slug(attributes[:slug] || name.parameterize) || create(name: name, **attributes)
      end
    end

    def slug
      self["id"]
    end

    def directory
      [parent_path, self["id"]].compact_blank.join("/")
    end

    def parent
      return nil if parent_path.blank?

      parent_id = File.basename(parent_path)
      grandparent_path = File.dirname(parent_path)
      grandparent_path = nil if grandparent_path == "."

      self.class.find_by_file_path(self.class.path_for({parent_path: grandparent_path, id: parent_id}, root: path_root))
    end

    def children
      self.class.all.select { |series| series.parent_path == directory }
    end

    def ancestors
      parent ? [*parent.ancestors, parent] : []
    end

    def default_image(filename)
      file = default_images[filename]

      file&.exist? ? file : parent&.default_image(filename)
    end

    def banner_background
      self["banner_background"].presence || parent&.banner_background
    end

    def featured_background
      self["featured_background"].presence || parent&.featured_background
    end

    def featured_color
      self["featured_color"].presence || parent&.featured_color
    end

    def old_ids
      Array(self["old_ids"]).compact_blank
    end

    def old_event_ids
      Array(self["old_event_ids"]).compact_blank
    end

    def removed_talk_ids
      Array(self["removed_talk_ids"]).compact_blank
    end

    def event_series_record
      @event_series_record ||= ::EventSeries.find_by(slug: slug) || import_series!
    end

    def import_series!(index: SEARCH_INDEX_ON_IMPORT_DEFAULT)
      event_series = ::EventSeries.find_by(slug: slug) || renamed_series_record || ::EventSeries.new(slug: slug)

      event_series.update!(
        name: name,
        description: self["description"] || "",
        website: website || "",
        twitter: twitter || "",
        kind: kind,
        slug: slug,
        language: language || "",
        parent: parent&.event_series_record,
        location: self["location"] || "",
        city: resolved_city,
        state_code: state_code,
        country_code: country&.alpha2,
        latitude: coordinates_hash["latitude"],
        longitude: coordinates_hash["longitude"]
      )

      event_series.sync_aliases_from_list(aliases) if aliases.present?
      sync_old_slugs!(event_series)

      Search::Backend.index(event_series) if index

      event_series
    end

    def renamed_series_record
      old_ids.each do |old_id|
        event_series = ::EventSeries.find_by(slug: old_id)
        return event_series if event_series
      end

      nil
    end

    def sync_old_slugs!(event_series)
      old_ids.each do |old_id|
        next if ::Alias.exists?(slug: old_id)

        event_series.aliases.create!(name: old_id, slug: old_id)
      end
    end

    def import!(index: SEARCH_INDEX_ON_IMPORT_DEFAULT)
      event_series = import_series!(index: index)
      events.each { |event| event.import!(index: index) }

      import_cfps_into!(event_series, cfps) if cfps.exist?
      import_sponsors_into!(event_series, sponsors) if sponsors.exist?
      import_involvements_into!(event_series, involvements) if involvements.exist?

      merge_old_events!(event_series)
      update_frequency!(event_series)

      event_series
    end

    def move_speaker_participations!(event, event_series)
      speaker_ids = event.event_participations.where(role: "speaker").select(:user_id)

      ::UserTalk.kept.joins(:talk).where(user_id: speaker_ids, talks: {event_id: event_series.events.where.not(id: event.id).select(:id)})
        .includes(:user, talk: :event).find_each do |user_talk|
        ::EventParticipation.record(user: user_talk.user, event: user_talk.talk.event, role: "speaker")
      end
    end

    def move_attendee_participations!(event, meetups)
      event.event_participations.where.not(role: "speaker").includes(:user).find_each do |participation|
        marked_on = participation.created_at.to_date
        meetup = if participation.interested?
          meetups.find { |candidate| candidate.start_date >= marked_on } || meetups.last
        else
          meetups.rfind { |candidate| candidate.start_date <= marked_on } || meetups.first
        end

        ::EventParticipation.record(user: participation.user, event: meetup, role: participation.role)
      end

      ::EventCheckIn.where(event: event).find_each do |check_in|
        checked_in_on = check_in.checked_in_at.to_date
        meetup = meetups.rfind { |candidate| candidate.start_date <= checked_in_on } || meetups.first

        check_in.update!(event: meetup) unless ::EventCheckIn.exists?(connect_id: check_in.connect_id, event: meetup)
      end
      ::EventCheckIn.where(event: event).delete_all
    end

    def update_frequency!(event_series)
      frequency = ::EventSeries.includes(:events).find(event_series.id).computed_frequency || :unknown
      event_series.update!(frequency: frequency)
    end

    def merge_old_events!(event_series)
      return if old_event_ids.empty?

      ::Event.where(slug: old_event_ids).find_each do |event|
        event.talks.where(static_id: removed_talk_ids).destroy_all if removed_talk_ids.any?
        remaining_talks = event.talks.reject { |talk| talk.meta_talk? && talk.child_talks.none? }

        if remaining_talks.any?
          puts "::warning::Event #{event.slug} still has #{remaining_talks.size} talks (#{remaining_talks.first(3).map(&:static_id).join(", ")}), so it isn't merged into #{event_series.slug} yet"
          next
        end

        meetups = event_series.events.where(kind: :meetup).where.not(start_date: nil).where.not(id: event.id).order(:start_date).to_a

        if meetups.empty? && (event.event_participations.where.not(role: "speaker").exists? || ::EventCheckIn.exists?(event: event))
          puts "::warning::Event #{event.slug} has attendees but #{event_series.slug} has no meetups to move them to, so it isn't merged yet"
          next
        end

        event.cfps.update_all(event_id: nil, event_series_id: event_series.id) unless cfps.exist?
        event.sponsors.update_all(event_id: nil, event_series_id: event_series.id) unless sponsors.exist?
        event.event_involvements.update_all(event_id: nil, event_series_id: event_series.id) unless involvements.exist?

        [event.slug, *event.slug_aliases.pluck(:slug)].compact_blank.uniq.each do |old_slug|
          ::Alias.where(aliasable_type: "Event", slug: old_slug).delete_all

          next if ::Alias.exists?(slug: old_slug) || ::Alias.exists?(aliasable_type: "EventSeries", name: old_slug)

          event_series.aliases.create!(name: old_slug, slug: old_slug)
        end

        move_speaker_participations!(event, event_series)
        move_attendee_participations!(event, meetups) if meetups.any?

        event.slug_aliases.reload
        event.reload.destroy!
      end

      (old_event_ids - ::Event.where(slug: old_event_ids).pluck(:slug)).each do |old_slug|
        next if ::Alias.exists?(slug: old_slug) || ::Alias.exists?(aliasable_type: "EventSeries", name: old_slug)

        event_series.aliases.create!(name: old_slug, slug: old_slug)
      end
    end

    def coordinates_hash
      self["coordinates"].is_a?(Hash) ? self["coordinates"] : {}
    end

    def all_youtube_channels
      @all_youtube_channels ||= Array(self["youtube_channels"] || [])
    end

    def all_youtube_channel_ids
      all_youtube_channels.map { |channel| channel["id"] }.compact
    end

    has_many :events, foreign_key: :series_slug
    has_many :cfps, class_name: "Static::SeriesCFP"
    has_many :sponsors, class_name: "Static::SeriesSponsor"
    has_many :involvements, class_name: "Static::SeriesInvolvement"
    has_files :images, "app/assets/images/events/:id"
    has_files :default_images, "app/assets/images/events/:id/default"

    def persist_path
      return nil if self["id"].blank?

      self.class.path_for({parent_path: parent_path, id: self["id"]})
    end
  end
end
