namespace :db do
  namespace :seed do
    desc "Seed all contributions, event, speaker, and more data"
    task all: :environment do
      Search::Backend.without_indexing do
        Static::City.import_all!
        Static::Speaker.import_all!
        Static::EventSeries.import_all!
        Static::Topic.import_all!

        Rake::Task["backfill:speaker_participation"].invoke
        Rake::Task["backfill:event_involvements"].invoke
        Rake::Task["speakerdeck:set_usernames_from_slides_url"].invoke

        begin
          Rake::Task["contributors:fetch"].invoke
        rescue ApplicationClient::Unauthorized, ApplicationClient::Forbidden => e
          puts "Skipping fetching contributors: #{e.message}"
        end
      end

      Search::Backend.reindex_all
    end

    desc "Seed one event series by passing the event series slug - db:seed:event_series[rubyconf]"
    task :event_series, [:slug] => :environment do |task, args|
      event = Static::EventSeries.find_by_slug(args[:slug])
      if event
        event.import!
      else
        puts "Event Series with slug '#{args[:slug]}' not found."
      end
    end

    desc "Seed all events without series - will error on new event series"
    task events: :environment do
      Static::Event.import_all!
    end

    desc "Seed all speakers"
    task speakers: :environment do
      Static::Speaker.import_all!
    end
  end
end
