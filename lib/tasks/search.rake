# frozen_string_literal: true

namespace :search do
  desc "Reindex all search backends"
  task reindex: :environment do
    puts "Starting search reindex..."
    start_time = Time.current

    Search::Backend.reindex_all

    duration = Time.current - start_time
    puts "\n🎉 Search reindex completed in #{duration.round(2)} seconds"
  end

  desc "Show search backend status"
  task status: :environment do
    puts "\n📊 Search Backend Status\n"

    Search::Backend.backends.each do |name, backend|
      status = backend.available? ? "✅ Available" : "❌ Unavailable"
      puts "#{name}: #{status}"
    end

    puts "\nDefault backend: #{Search::Backend.default_backend.name}"
  end
end

namespace :sqlite_fts do
  desc "Reindex all SQLite FTS indexes"
  task reindex: :environment do
    puts "Starting SQLite FTS reindex..."
    start_time = Time.current

    Search::Backend::SQLiteFTS::Indexer.reindex_all

    duration = Time.current - start_time
    puts "\n🎉 SQLite FTS reindex completed in #{duration.round(2)} seconds"
  end

  namespace :reindex do
    desc "Reindex Talks FTS index"
    task talks: :environment do
      count = Talk.watchable.count
      puts "\n📚 Reindexing #{count} Talks..."
      start = Time.current
      Search::Backend::SQLiteFTS::Indexer.reindex_talks
      puts "   ✅ Talks reindexed in #{(Time.current - start).round(2)}s"
    end

    desc "Reindex Users FTS index"
    task users: :environment do
      count = User.speakers.canonical.count
      puts "\n👤 Reindexing #{count} Users..."
      start = Time.current
      Search::Backend::SQLiteFTS::Indexer.reindex_users
      puts "   ✅ Users reindexed in #{(Time.current - start).round(2)}s"
    end
  end
end
