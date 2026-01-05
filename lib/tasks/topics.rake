namespace :topics do
  desc "Use LLM to suggest gem mappings for topics"
  task suggest_gems: :environment do
    require "json"

    limit = ENV.fetch("LIMIT", 50).to_i
    offset = ENV.fetch("OFFSET", 0).to_i
    min_talks = ENV.fetch("MIN_TALKS", 3).to_i

    topics = Topic
      .approved
      .canonical
      .left_joins(:topic_gems)
      .where(topic_gems: {id: nil})
      .where("talks_count >= ?", min_talks)
      .order(talks_count: :desc)
      .offset(offset)
      .limit(limit)

    if topics.empty?
      puts "No topics without gem mappings found."
      exit
    end

    puts "Found #{topics.count} topics without gem mappings (min #{min_talks} talks, offset #{offset})"
    puts "Sending to LLM for suggestions...\n\n"

    prompt = Prompts::Topic::SuggestGems.new(topics: topics)
    client = OpenAI::Client.new

    response = client.chat(parameters: prompt.to_params)

    content = response.dig("choices", 0, "message", "content")
    suggestions = JSON.parse(content)["suggestions"]

    puts "=" * 60
    puts "GEM MAPPING SUGGESTIONS"
    puts "=" * 60
    puts

    accepted = []
    skipped = []

    suggestions.each do |suggestion|
      topic_name = suggestion["topic_name"]
      gem_names = suggestion["gem_names"]
      confidence = suggestion["confidence"]
      reasoning = suggestion["reasoning"]

      topic = topics.find { |t| t.name == topic_name }
      next unless topic

      if gem_names.empty?
        puts "#{topic_name} (#{topic.talks_count} talks)"
        puts "  No gems suggested: #{reasoning}"
        puts
        next
      end

      puts "-" * 60
      puts "Topic: #{topic_name} (#{topic.talks_count} talks)"
      puts "Suggested gems: #{gem_names.join(", ")}"
      puts "Confidence: #{confidence}"
      puts "Reasoning: #{reasoning}"
      puts

      valid_gems = gem_names.select do |gem_name|
        info = Gems.info(gem_name)

        if info.is_a?(Hash)
          puts "  ✓ #{gem_name} exists (v#{info["version"]}, #{ActiveSupport::NumberHelper.number_to_human(info["downloads"])} downloads)"
          true
        else
          puts "  ✗ #{gem_name} not found on RubyGems"
          false
        end
      rescue => e
        puts "  ✗ #{gem_name} error: #{e.message}"
        false
      end

      if valid_gems.empty?
        puts "  No valid gems found, skipping."
        puts
        next
      end

      print "\nAccept mapping? [y]es / [n]o / [s]kip all / [a]ccept all: "
      input = $stdin.gets&.strip&.downcase

      case input
      when "y", "yes"
        valid_gems.each do |gem_name|
          TopicGem.find_or_create_by!(topic: topic, gem_name: gem_name)
          puts "  → Added #{gem_name} to #{topic_name}"
        end
        accepted << {topic: topic_name, gems: valid_gems}

      when "a", "accept all"
        valid_gems.each do |gem_name|
          TopicGem.find_or_create_by!(topic: topic, gem_name: gem_name)
          puts "  → Added #{gem_name} to #{topic_name}"
        end

        accepted << {topic: topic_name, gems: valid_gems}

        remaining = suggestions[suggestions.index(suggestion) + 1..]

        remaining&.each do |remaining_suggestion|
          remaining_topic = topics.find { |t| t.name == remaining_suggestion["topic_name"] }
          next unless remaining_topic

          remaining_gems = remaining_suggestion["gem_names"].select do |gem_name|
            Gems.info(gem_name).is_a?(Hash)
          rescue
            false
          end

          remaining_gems.each do |gem_name|
            TopicGem.find_or_create_by!(topic: remaining_topic, gem_name: gem_name)
            puts "  → Added #{gem_name} to #{remaining_suggestion["topic_name"]}"
          end
          accepted << {topic: remaining_suggestion["topic_name"], gems: remaining_gems} if remaining_gems.any?
        end

        break
      when "s", "skip all"
        skipped << {topic: topic_name, gems: valid_gems}
        break
      else
        skipped << {topic: topic_name, gems: valid_gems}
        puts "  Skipped."
      end

      puts
    end

    puts
    puts "=" * 60
    puts "SUMMARY"
    puts "=" * 60
    puts "Accepted: #{accepted.count} topics"
    accepted.each { |a| puts "  - #{a[:topic]}: #{a[:gems].join(", ")}" }
    puts "Skipped: #{skipped.count} topics"
    puts
  end

  desc "List topics with gem mappings"
  task list_gems: :environment do
    topics = Topic.approved.joins(:topic_gems).distinct.order(:name)

    puts "Topics with gem mappings:"
    puts "-" * 40

    topics.each do |topic|
      gems = topic.topic_gems.pluck(:gem_name).join(", ")
      puts "#{topic.name}: #{gems}"
    end

    puts
    puts "Total: #{topics.count} topics with gem mappings"
    puts "Total gem mappings: #{TopicGem.count}"
  end
end
