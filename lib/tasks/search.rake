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

namespace :typesense do
  desc "Reindex all Typesense collections (zero-downtime using aliases)"
  task reindex: :environment do
    puts "Starting Typesense reindex..."

    start_time = Time.current

    Rake::Task["typesense:reindex:talks"].invoke
    Rake::Task["typesense:reindex:events"].invoke
    Rake::Task["typesense:reindex:users"].invoke
    Rake::Task["typesense:reindex:topics"].invoke
    Rake::Task["typesense:reindex:series"].invoke
    Rake::Task["typesense:reindex:organizations"].invoke
    Rake::Task["typesense:reindex:locations"].invoke
    Rake::Task["typesense:reindex:kinds"].invoke
    Rake::Task["typesense:reindex:languages"].invoke

    duration = Time.current - start_time
    puts "\n🎉 Typesense reindex completed in #{duration.round(2)} seconds"
  end

  namespace :reindex do
    desc "Reindex Talks collection"
    task talks: :environment do
      unless Talk.respond_to?(:typesense_index)
        puts "Typesense not enabled for Talk model"
        next
      end

      count = Talk.count
      puts "\n📚 Reindexing #{count} Talks..."
      start = Time.current
      Search::Backend::Typesense::Indexer.reindex_talks
      puts "   ✅ Talks reindexed in #{(Time.current - start).round(2)}s"
    end

    desc "Reindex Events collection"
    task events: :environment do
      unless Event.respond_to?(:typesense_index)
        puts "Typesense not enabled for Event model"
        next
      end

      count = Event.canonical.count
      puts "\n📅 Reindexing #{count} Events..."
      start = Time.current
      Search::Backend::Typesense::Indexer.reindex_events
      puts "   ✅ Events reindexed in #{(Time.current - start).round(2)}s"
    end

    desc "Reindex Users/Speakers collection"
    task users: :environment do
      unless User.respond_to?(:typesense_index)
        puts "Typesense not enabled for User model"
        next
      end

      count = User.where("talks_count > 0").where(canonical_id: nil).count
      puts "\n👤 Reindexing #{count} Users..."
      start = Time.current
      Search::Backend::Typesense::Indexer.reindex_users
      puts "   ✅ Users reindexed in #{(Time.current - start).round(2)}s"
    end

    desc "Reindex Topics collection"
    task topics: :environment do
      unless Topic.respond_to?(:typesense_index)
        puts "Typesense not enabled for Topic model"
        next
      end

      count = Topic.approved.canonical.with_talks.count
      puts "\n🏷️  Reindexing #{count} Topics..."
      start = Time.current
      Search::Backend::Typesense::Indexer.reindex_topics
      puts "   ✅ Topics reindexed in #{(Time.current - start).round(2)}s"
    end

    desc "Reindex EventSeries collection"
    task series: :environment do
      unless EventSeries.respond_to?(:typesense_index)
        puts "Typesense not enabled for EventSeries model"
        next
      end

      count = EventSeries.joins(:events).distinct.count
      puts "\n📺 Reindexing #{count} Event Series..."
      start = Time.current
      Search::Backend::Typesense::Indexer.reindex_series
      puts "   ✅ Event Series reindexed in #{(Time.current - start).round(2)}s"
    end

    desc "Reindex Organizations collection"
    task organizations: :environment do
      unless Organization.respond_to?(:typesense_index)
        puts "Typesense not enabled for Organization model"
        next
      end

      count = Organization.joins(:sponsors).distinct.count
      puts "\n🏢 Reindexing #{count} Organizations..."
      start = Time.current
      Search::Backend::Typesense::Indexer.reindex_organizations
      puts "   ✅ Organizations reindexed in #{(Time.current - start).round(2)}s"
    end

    desc "Reindex Locations collection (continents, countries, states, cities)"
    task locations: :environment do
      puts "\n🌍 Reindexing Locations..."
      start = Time.current
      Search::Backend::Typesense::LocationIndexer.reindex_all
      puts "   ✅ Locations reindexed in #{(Time.current - start).round(2)}s"
    end

    desc "Reindex Kinds collection (talk and event types)"
    task kinds: :environment do
      puts "\n🏷️ Reindexing Kinds..."
      start = Time.current
      Search::Backend::Typesense::KindIndexer.reindex_all
      puts "   ✅ Kinds reindexed in #{(Time.current - start).round(2)}s"
    end

    desc "Reindex Languages collection"
    task languages: :environment do
      count = Language.used.count
      puts "\n🗣️ Reindexing #{count} Languages..."
      start = Time.current
      Search::Backend::Typesense::LanguageIndexer.reindex_all
      puts "   ✅ Languages reindexed in #{(Time.current - start).round(2)}s"
    end

    desc "Reindex Continents"
    task continents: :environment do
      puts "\n🌍 Reindexing Continents..."
      start = Time.current
      Search::Backend::Typesense::LocationIndexer.ensure_collection!
      Search::Backend::Typesense::LocationIndexer.index_continents
      puts "   ✅ Continents reindexed in #{(Time.current - start).round(2)}s"
    end

    desc "Reindex Countries"
    task countries: :environment do
      puts "\n🏳️ Reindexing Countries..."
      start = Time.current
      Search::Backend::Typesense::LocationIndexer.ensure_collection!
      Search::Backend::Typesense::LocationIndexer.index_countries
      puts "   ✅ Countries reindexed in #{(Time.current - start).round(2)}s"
    end

    desc "Reindex States"
    task states: :environment do
      puts "\n🗺️ Reindexing States..."
      start = Time.current
      Search::Backend::Typesense::LocationIndexer.ensure_collection!
      Search::Backend::Typesense::LocationIndexer.index_states
      puts "   ✅ States reindexed in #{(Time.current - start).round(2)}s"
    end

    desc "Reindex Cities"
    task cities: :environment do
      puts "\n🏙️ Reindexing Cities..."
      start = Time.current
      Search::Backend::Typesense::LocationIndexer.ensure_collection!
      Search::Backend::Typesense::LocationIndexer.index_cities
      puts "   ✅ Cities reindexed in #{(Time.current - start).round(2)}s"
    end
  end

  desc "Index a single record (usage: rake typesense:index[Talk,123] or typesense:index[Event,railsconf-2024])"
  task :index, [:model, :id] => :environment do |_t, args|
    model_name = args[:model]
    id = args[:id]

    unless model_name && id
      puts "Usage: rake typesense:index[Model,id]"
      puts "Examples:"
      puts "  rake typesense:index[Talk,123]"
      puts "  rake typesense:index[Talk,my-talk-slug]"
      puts "  rake typesense:index[Event,railsconf-2024]"
      puts "  rake typesense:index[User,456]"
      next
    end

    model = model_name.constantize
    record = model.find_by(id: id) || model.find_by(slug: id)

    unless record
      puts "❌ #{model_name} with id/slug '#{id}' not found"
      next
    end

    Search::Backend::Typesense::Indexer.index(record)
    puts "✅ Indexed #{model_name} ##{record.id}: #{record.try(:title) || record.try(:name)}"
  end

  desc "Remove a single record from index (usage: rake typesense:remove[Talk,123])"
  task :remove, [:model, :id] => :environment do |_t, args|
    model_name = args[:model]
    id = args[:id]

    unless model_name && id
      puts "Usage: rake typesense:remove[Model,id]"
      next
    end

    model = model_name.constantize
    record = model.find_by(id: id) || model.find_by(slug: id)

    unless record
      puts "❌ #{model_name} with id/slug '#{id}' not found"
      next
    end

    Search::Backend::Typesense::Indexer.remove(record)
    puts "✅ Removed #{model_name} ##{record.id} from index"
  end

  desc "Incrementally index recent records (usage: rake typesense:index_recent or typesense:index_recent[48])"
  task :index_recent, [:hours] => :environment do |_t, args|
    hours = (args[:hours] || 24).to_i
    since = hours.hours.ago

    puts "Indexing records modified in the last #{hours} hours..."

    if Talk.respond_to?(:typesense_index!)
      talks = Talk.where("updated_at > ?", since)
      puts "\n📚 Indexing #{talks.count} talks..."
      talks.find_each { |t| Search::Backend::Typesense::Indexer.index(t) }
    end

    if Event.respond_to?(:typesense_index!)
      events = Event.canonical.where("updated_at > ?", since)
      puts "📅 Indexing #{events.count} events..."
      events.find_each { |e| Search::Backend::Typesense::Indexer.index(e) }
    end

    if User.respond_to?(:typesense_index!)
      users = User.where("talks_count > 0").where(canonical_id: nil).where("updated_at > ?", since)
      puts "👤 Indexing #{users.count} users..."
      users.find_each { |u| Search::Backend::Typesense::Indexer.index(u) }
    end

    if Topic.respond_to?(:typesense_index!)
      topics = Topic.approved.canonical.with_talks.where("updated_at > ?", since)
      puts "🏷️  Indexing #{topics.count} topics..."
      topics.find_each { |t| Search::Backend::Typesense::Indexer.index(t) }
    end

    puts "\n✅ Done!"
  end

  desc "Clear all Typesense collections"
  task clear: :environment do
    puts "Clearing all Typesense collections..."

    [Talk, Event, User, Topic].each do |model|
      if model.respond_to?(:clear_index!)
        begin
          model.clear_index!
        rescue
          nil
        end
        puts "   Cleared #{model.name} collection"
      end
    end

    puts "✅ All collections cleared!"
  end

  namespace :clear do
    desc "Clear Talks collection"
    task talks: :environment do
      Talk.clear_index! if Talk.respond_to?(:clear_index!)
      puts "✅ Talk collection cleared"
    end

    desc "Clear Events collection"
    task events: :environment do
      Event.clear_index! if Event.respond_to?(:clear_index!)
      puts "✅ Event collection cleared"
    end

    desc "Clear Users collection"
    task users: :environment do
      User.clear_index! if User.respond_to?(:clear_index!)
      puts "✅ User collection cleared"
    end

    desc "Clear Topics collection"
    task topics: :environment do
      Topic.clear_index! if Topic.respond_to?(:clear_index!)
      puts "✅ Topic collection cleared"
    end
  end

  desc "Drop all Typesense collections (deletes schema, requires reindex)"
  task drop: :environment do
    puts "Dropping all Typesense collections..."
    client = Typesense::Client.new(Typesense.configuration)

    %w[Talk Event User Topic EventSeries Organization locations kinds languages].each do |name|
      client.collections[name].delete
      puts "   Dropped #{name} collection"
    rescue Typesense::Error::ObjectNotFound
      puts "   #{name} collection not found (skipping)"
    end

    puts "✅ All collections dropped!"
  end

  namespace :drop do
    desc "Drop Talks collection (deletes schema)"
    task talks: :environment do
      client = Typesense::Client.new(Typesense.configuration)
      client.collections["Talk"].delete
      puts "✅ Talk collection dropped"
    rescue Typesense::Error::ObjectNotFound
      puts "Talk collection not found"
    end

    desc "Drop Events collection (deletes schema)"
    task events: :environment do
      client = Typesense::Client.new(Typesense.configuration)
      client.collections["Event"].delete
      puts "✅ Event collection dropped"
    rescue Typesense::Error::ObjectNotFound
      puts "Event collection not found"
    end

    desc "Drop Users collection (deletes schema)"
    task users: :environment do
      client = Typesense::Client.new(Typesense.configuration)
      client.collections["User"].delete
      puts "✅ User collection dropped"
    rescue Typesense::Error::ObjectNotFound
      puts "User collection not found"
    end

    desc "Drop Topics collection (deletes schema)"
    task topics: :environment do
      client = Typesense::Client.new(Typesense.configuration)
      client.collections["Topic"].delete
      puts "✅ Topic collection dropped"
    rescue Typesense::Error::ObjectNotFound
      puts "Topic collection not found"
    end

    desc "Drop EventSeries collection (deletes schema)"
    task series: :environment do
      client = Typesense::Client.new(Typesense.configuration)
      client.collections["EventSeries"].delete
      puts "✅ EventSeries collection dropped"
    rescue Typesense::Error::ObjectNotFound
      puts "EventSeries collection not found"
    end

    desc "Drop Organizations collection (deletes schema)"
    task organizations: :environment do
      client = Typesense::Client.new(Typesense.configuration)
      client.collections["Organization"].delete
      puts "✅ Organization collection dropped"
    rescue Typesense::Error::ObjectNotFound
      puts "Organization collection not found"
    end

    desc "Drop locations collection (deletes schema)"
    task locations: :environment do
      client = Typesense::Client.new(Typesense.configuration)
      client.collections["locations"].delete
      puts "✅ locations collection dropped"
    rescue Typesense::Error::ObjectNotFound
      puts "locations collection not found"
    end

    desc "Drop kinds collection (deletes schema)"
    task kinds: :environment do
      client = Typesense::Client.new(Typesense.configuration)
      client.collections["kinds"].delete
      puts "✅ kinds collection dropped"
    rescue Typesense::Error::ObjectNotFound
      puts "kinds collection not found"
    end

    desc "Drop languages collection (deletes schema)"
    task languages: :environment do
      client = Typesense::Client.new(Typesense.configuration)
      client.collections["languages"].delete
      puts "✅ languages collection dropped"
    rescue Typesense::Error::ObjectNotFound
      puts "languages collection not found"
    end
  end

  desc "Show Typesense collection stats"
  task stats: :environment do
    puts "\n📊 Typesense Collection Stats\n"

    begin
      client = Typesense::Client.new(Typesense.configuration)
      collections = client.collections.retrieve

      if collections.empty?
        puts "No collections found."
        next
      end

      collections.sort_by { |c| c["name"] }.each do |collection|
        puts "#{collection["name"]}:"
        puts "   Documents: #{collection["num_documents"]}"
        puts "   Fields: #{collection["fields"].size}"
        puts ""
      end

      # Show DB counts for comparison
      puts "Database counts:"
      puts "   Talks (all): #{Talk.count}"
      puts "   Events (canonical): #{Event.canonical.count}"
      puts "   Users (speakers): #{User.where("talks_count > 0").where(canonical_id: nil).count}"
      puts "   Topics (approved): #{Topic.approved.canonical.with_talks.count}"
    rescue => e
      puts "Error: #{e.message}"
    end
  end

  desc "Test Typesense connection"
  task health: :environment do
    puts "Testing Typesense connection..."

    available = Search::Backend::Typesense.available?

    if available
      puts "✅ Typesense is healthy!"
    else
      puts "❌ Typesense is not available"
      puts ""
      puts "Make sure Typesense is running:"
      puts "   docker compose -f docker-compose.typesense.yml up -d"
    end
  end

  desc "Search across all collections (usage: rake typesense:search[query])"
  task :search, [:query] => :environment do |_t, args|
    query = args[:query] || "*"
    puts "Searching for: #{query}\n\n"

    backend = Search::Backend::Typesense

    results, count = backend.search_talks(query, limit: 5)
    puts "📚 Talks (#{count} found):"
    if results.any?
      results.each do |talk|
        puts "   - #{talk.title}"
        puts "     by #{talk.speaker_names} at #{talk.event_name}"
      end
    else
      puts "   (no results)"
    end

    puts ""

    results, count = backend.search_speakers(query, limit: 5)
    puts "👤 Speakers (#{count} found):"
    if results.any?
      results.each do |user|
        puts "   - #{user.name} (#{user.talks_count} talks)"
      end
    else
      puts "   (no results)"
    end

    puts ""

    results, count = backend.search_events(query, limit: 5)
    puts "📅 Events (#{count} found):"
    if results.any?
      results.each do |event|
        puts "   - #{event.name} (#{event.talks_count} talks)"
      end
    else
      puts "   (no results)"
    end

    puts ""

    results, count = backend.search_topics(query, limit: 5)
    puts "🏷️  Topics (#{count} found):"
    if results.any?
      results.each do |topic|
        puts "   - #{topic.name} (#{topic.talks_count} talks)"
      end
    else
      puts "   (no results)"
    end

    puts ""

    results, count = backend.search_series(query, limit: 5)
    puts "📺 Series (#{count} found):"
    if results.any?
      results.each do |series|
        puts "   - #{series.name}"
      end
    else
      puts "   (no results)"
    end

    puts ""

    results, count = backend.search_organizations(query, limit: 5)
    puts "🏢 Organizations (#{count} found):"
    if results.any?
      results.each do |org|
        puts "   - #{org.name}"
      end
    else
      puts "   (no results)"
    end

    puts ""

    results, count = backend.search_locations(query, limit: 10)
    puts "🌍 Locations (#{count} found):"
    if results.any?
      results.each do |loc|
        type_emoji = {continent: "🌍", country: "🏳️", state: "🗺️", city: "🏙️"}[loc[:type].to_sym] || "📍"
        puts "   #{type_emoji} #{loc[:emoji_flag]} #{loc[:name]} (#{loc[:type]}, #{loc[:event_count]} events)"
      end
    else
      puts "   (no results)"
    end

    puts ""

    results, count = backend.search_languages(query, limit: 10)
    puts "🗣️ Languages (#{count} found):"
    if results.any?
      results.each do |lang|
        puts "   - #{lang[:name]} (#{lang[:code]}, #{lang[:talk_count]} talks)"
      end
    else
      puts "   (no results)"
    end
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
      count = Talk.count
      puts "\n📚 Reindexing #{count} Talks..."
      start = Time.current
      Search::Backend::SQLiteFTS::Indexer.reindex_talks
      puts "   ✅ Talks reindexed in #{(Time.current - start).round(2)}s"
    end

    desc "Reindex Users FTS index"
    task users: :environment do
      count = User.indexable.count
      puts "\n👤 Reindexing #{count} Users..."
      start = Time.current
      Search::Backend::SQLiteFTS::Indexer.reindex_users
      puts "   ✅ Users reindexed in #{(Time.current - start).round(2)}s"
    end
  end
end
