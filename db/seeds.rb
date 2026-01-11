Static::Speaker.import_all!
Static::EventSeries.import_all_series!
Static::Event.import_recent!
Static::Event.import_meetups!
Static::Topic.import_all!
Static::City.import_all!

User.order(Arel.sql("RANDOM()")).limit(5).each do |user|
  user.watched_talk_seeder.seed_development_data
end

Rake::Task["backfill:speaker_participation"].invoke
