namespace :db do
  namespace :seed do
    desc "Force a full re-import of every data/ file, ignoring fingerprints"
    task all: :environment do
      ENV["FORCE_SEED"] = "1"
      Rake::Task["db:seed"].invoke
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
      Search::Backend.without_indexing do
        Static::Event.import_all!
      end
    end

    desc "Seed all meetups"
    task meetups: :environment do
      Search::Backend.without_indexing do
        Static::Event.import_meetups!
      end
    end

    desc "Seed all speakers"
    task speakers: :environment do
      Search::Backend.without_indexing do
        Static::Speaker.import_all!
      end
    end
  end
end
