# frozen_string_literal: true

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

      count = Talk.watchable.count
      puts "\n📚 Reindexing #{count} Talks..."
      start = Time.current
      Talk.reindex
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
      Event.reindex
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
      User.reindex
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
      Topic.reindex
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
      EventSeries.reindex
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
      Organization.reindex
      puts "   ✅ Organizations reindexed in #{(Time.current - start).round(2)}s"
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

    unless record.respond_to?(:typesense_index!)
      puts "❌ Typesense not enabled for #{model_name}"
      next
    end

    record.typesense_index!
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

    unless record.respond_to?(:typesense_remove_from_index!)
      puts "❌ Typesense not enabled for #{model_name}"
      next
    end

    record.typesense_remove_from_index!
    puts "✅ Removed #{model_name} ##{record.id} from index"
  end

  desc "Incrementally index recent records (usage: rake typesense:index_recent or typesense:index_recent[48])"
  task :index_recent, [:hours] => :environment do |_t, args|
    hours = (args[:hours] || 24).to_i
    since = hours.hours.ago

    puts "Indexing records modified in the last #{hours} hours..."

    if Talk.respond_to?(:typesense_index!)
      talks = Talk.watchable.where("updated_at > ?", since)
      puts "\n📚 Indexing #{talks.count} talks..."
      talks.find_each { |t|
        begin
          t.typesense_index!
        rescue
          nil
        end
      }
    end

    if Event.respond_to?(:typesense_index!)
      events = Event.canonical.where("updated_at > ?", since)
      puts "📅 Indexing #{events.count} events..."
      events.find_each { |e|
        begin
          e.typesense_index!
        rescue
          nil
        end
      }
    end

    if User.respond_to?(:typesense_index!)
      users = User.where("talks_count > 0").where(canonical_id: nil).where("updated_at > ?", since)
      puts "👤 Indexing #{users.count} users..."
      users.find_each { |u|
        begin
          u.typesense_index!
        rescue
          nil
        end
      }
    end

    if Topic.respond_to?(:typesense_index!)
      topics = Topic.approved.canonical.with_talks.where("updated_at > ?", since)
      puts "🏷️  Indexing #{topics.count} topics..."
      topics.find_each { |t|
        begin
          t.typesense_index!
        rescue
          nil
        end
      }
    end

    puts "\n✅ Done!"
  end

  desc "Clear all Typesense collections"
  task clear: :environment do
    puts "Clearing all Typesense collections..."

    if Talk.respond_to?(:clear_index!)
      begin
        Talk.clear_index!
      rescue
        nil
      end
      puts "   Cleared Talk collection"
    end

    if Event.respond_to?(:clear_index!)
      begin
        Event.clear_index!
      rescue
        nil
      end
      puts "   Cleared Event collection"
    end

    if User.respond_to?(:clear_index!)
      begin
        User.clear_index!
      rescue
        nil
      end
      puts "   Cleared User collection"
    end

    if Topic.respond_to?(:clear_index!)
      begin
        Topic.clear_index!
      rescue
        nil
      end
      puts "   Cleared Topic collection"
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
      puts "   Talks (watchable): #{Talk.watchable.count}"
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

    begin
      client = Typesense::Client.new(Typesense.configuration)
      health = client.health.retrieve

      if health["ok"]
        puts "✅ Typesense is healthy!"
      else
        puts "⚠️  Typesense is not healthy"
      end

      puts "   Status: #{health}"
    rescue => e
      puts "❌ Failed to connect to Typesense"
      puts "   Error: #{e.message}"
      puts ""
      puts "Make sure Typesense is running:"
      puts "   docker compose -f docker-compose.typesense.yml up -d"
    end
  end

  desc "Search across all collections (usage: rake typesense:search[query])"
  task :search, [:query] => :environment do |_t, args|
    query = args[:query] || "*"
    puts "Searching for: #{query}\n\n"

    if Talk.respond_to?(:typesense_search_talks)
      pagy, results = Talk.typesense_search_talks(query, per_page: 10)
      puts "📚 Talks (#{pagy.count} found):"
      if results.any?
        results.first(5).each do |talk|
          puts "   - #{talk.title}"
          puts "     by #{talk.speaker_names} at #{talk.event_name}"
        end
      else
        puts "   (no results)"
      end
    end

    puts ""

    if User.respond_to?(:typesense_search_speakers)
      pagy, results = User.typesense_search_speakers(query, per_page: 10)
      puts "👤 Speakers (#{pagy.count} found):"
      if results.any?
        results.first(5).each do |user|
          puts "   - #{user.name} (#{user.talks_count} talks)"
        end
      else
        puts "   (no results)"
      end
    end

    puts ""

    if Event.respond_to?(:typesense_search_events)
      pagy, results = Event.typesense_search_events(query, per_page: 10)
      puts "📅 Events (#{pagy.count} found):"
      if results.any?
        results.first(5).each do |event|
          puts "   - #{event.name} (#{event.talks_count} talks)"
        end
      else
        puts "   (no results)"
      end
    end

    puts ""

    if Topic.respond_to?(:typesense_search_topics)
      pagy, results = Topic.typesense_search_topics(query, per_page: 10)
      puts "🏷️  Topics (#{pagy.count} found):"
      if results.any?
        results.first(5).each do |topic|
          puts "   - #{topic.name} (#{topic.talks_count} talks)"
        end
      else
        puts "   (no results)"
      end
    end

    puts ""

    if EventSeries.respond_to?(:typesense_search_series)
      pagy, results = EventSeries.typesense_search_series(query, per_page: 10)
      puts "📺 Series (#{pagy.count} found):"
      if results.any?
        results.first(5).each do |series|
          puts "   - #{series.name}"
        end
      else
        puts "   (no results)"
      end
    end

    puts ""

    if Organization.respond_to?(:typesense_search_organizations)
      pagy, results = Organization.typesense_search_organizations(query, per_page: 10)
      puts "🏢 Organizations (#{pagy.count} found):"
      if results.any?
        results.first(5).each do |org|
          puts "   - #{org.name}"
        end
      else
        puts "   (no results)"
      end
    end
  end
end
