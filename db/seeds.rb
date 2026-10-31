force = ENV["FORCE_SEED"].present?

result = Static::DataImporter.with_indexing_for(Static::DataImporter.changes.size, force: force) do
  Static::DataImporter.seed_changed!(force: force).tap do |seeded|
    next unless Static::DataImporter.changed?(seeded)

    Rake::Task["backfill:speaker_participation"].invoke
    Rake::Task["backfill:event_involvements"].invoke

    if Rails.env.development?
      User.order(Arel.sql("RANDOM()")).limit(5).each do |user|
        user.watched_talk_seeder.seed_development_data
      end
    end
  end
end

if result[:failed].any?
  raise Static::ImportError, "Failed to import #{result[:failed].size} data #{"file".pluralize(result[:failed].size)}:\n#{result[:failed].map { |path| "  #{path}" }.join("\n")}"
end
