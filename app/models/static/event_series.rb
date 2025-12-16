module Static
  class EventSeries < FrozenRecord::Base
    self.backend = Backends::MultiFileBackend.new("*/series.yml")
    self.base_path = Rails.root.join("data")

    class << self
      def find_by_slug(slug)
        @slug_index ||= all.index_by(&:slug)
        @slug_index[slug]
      end

      def import_all!
        all.each(&:import!)
      end

      def import_all_series!
        all.each(&:import_series!)
      end
    end

    def slug
      @slug ||= File.basename(File.dirname(__file_path))
    end

    def event_series_record
      @event_series_record ||= ::EventSeries.find_by(slug: slug) || import_series!
    end

    def import_series!
      event_series = ::EventSeries.find_or_initialize_by(slug: slug)

      event_series.update!(
        name: name,
        website: website || "",
        twitter: twitter || "",
        youtube_channel_name: youtube_channel_name,
        kind: kind,
        frequency: frequency,
        youtube_channel_id: youtube_channel_id,
        slug: slug,
        language: language || ""
      )

      event_series.sync_aliases_from_list(aliases) if aliases.present?

      event_series
    end

    def import!
      import_series!
      events.each(&:import!)
      event_series_record
    end

    def events
      @events ||= Static::Event.all.select { |event| event.series_slug == slug }
    end
  end
end
