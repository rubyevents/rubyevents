Search::Backend.without_indexing do
  Static::Importer.import_all!

  User.order(Arel.sql("RANDOM()")).limit(5).each do |user|
    user.watched_talk_seeder.seed_development_data
  end

  Rake::Task["backfill:speaker_participation"].invoke
end

Search::Backend.reindex_all
