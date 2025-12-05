Static::Speaker.import_all!
Static::EventSeries.import_all!
Static::Topic.import_all!

User.order(Arel.sql("RANDOM()")).limit(5).each do |user|
  user.watched_talk_seeder.seed_development_data
end

Rake::Task["backfill:speaker_participation"].invoke
Rake::Task["backfill:event_involvements"].invoke
Rake::Task["speakerdeck:set_usernames_from_slides_url"].invoke
Rake::Task["contributors:fetch"].invoke
