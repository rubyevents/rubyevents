# frozen_string_literal: true

module Static
  module Importer
    def self.import_all!
      Static::City.import_all!
      Static::Speaker.bulk_import!
      Static::EventSeries.import_all_series!
      Static::Event.bulk_import!
      Static::BulkTalkImport.run!
      import_event_associations!
      Static::Topic.import_all!
    end

    def self.import_event_associations!
      events_by_slug = ::Event.all.index_by(&:slug)

      Static::Event.all.each do |static_event|
        event = events_by_slug[static_event.slug]
        next unless event

        static_event.import_cfps!(event)
        static_event.import_involvements!(event)
        static_event.import_transcripts!(event)
      end

      Static::BulkSponsorImport.run!
    end
  end
end
