# frozen_string_literal: true

module Static
  class EventSeries < Yerba::Record::Base
    self.path = "data/:id/series.yml"

    schema SeriesSchema

    validates :id, matches_path: true, on: :lint
    validates_with Static::BrandColorsValidator, on: :lint

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
