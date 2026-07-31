result = Search::Backend.without_indexing do
  Static::DataImporter.seed_changed!(force: ENV["FORCE_SEED"].present?)
end

if result[:imported].positive?
  Rake::Task["backfill:speaker_participation"].invoke
  Rake::Task["backfill:event_involvements"].invoke

  if Rails.env.development?
    User.order(Arel.sql("RANDOM()")).limit(5).each do |user|
      user.watched_talk_seeder.seed_development_data
    end
  end

  Search::Backend.reindex_all
end
