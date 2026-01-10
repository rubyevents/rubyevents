namespace :db do
  namespace :seed do
    desc "Seed all contributions, event, speaker, and more data"
    task all: :environment do
      Search::Backend.without_indexing do
        Static::Speaker.import_all!
        Static::EventSeries.import_all!
        Static::Event.import_all!
        Static::Topic.import_all!
        Static::City.import_all!
      end

      Search::Backend.reindex_all

      Rake::Task["backfill:speaker_participation"].invoke
      Rake::Task["backfill:event_involvements"].invoke
      Rake::Task["speakerdeck:set_usernames_from_slides_url"].invoke
      begin
        Rake::Task["contributors:fetch"].invoke
      rescue ApplicationClient::Unauthorized, ApplicationClient::Forbidden => e
        puts "Skipping fetching contributors: #{e.message}"
      end
    end
  end
end
