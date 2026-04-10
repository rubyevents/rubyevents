class Topic::Agents < ActiveRecord::AssociatedObject
  performs retries: 2 do
    limits_concurrency to: 4, key: "openai_api", duration: 1.hour
  end

  performs def find_talks
    candidate_talks = find_candidate_talks
    existing_talk_ids = topic.talk_ids

    new_candidates = candidate_talks.reject { |talk| existing_talk_ids.include?(talk.id) }

    return if new_candidates.empty?

    confirmed_talks = filter_with_ai(new_candidates)

    return if confirmed_talks.empty?

    topic.talks << confirmed_talks

    Rails.logger.info "[Topic::Agents] Assigned #{confirmed_talks.size} talks to topic '#{topic.name}'"

    confirmed_talks
  end

  private

  def find_candidate_talks
    variants = name_variants
    talk_ids = Set.new

    variants.each do |variant|
      Talk.ft_search(variant).pluck(:id).each { |id| talk_ids << id }
    end

    Talk.where(id: talk_ids.to_a)
  end

  def name_variants
    name = topic.name

    variants = [
      name,
      name.delete(" "),
      name.tr(" ", "-"),
      name.tr(" ", "_"),
      name.tr("-", " "),
      name.delete("-"),
      name.tr("-", "_"),
      name.tr("_", " "),
      name.tr("_", "-"),
      name.delete("_")
    ]

    variants.map(&:downcase).uniq
  end

  def filter_with_ai(candidates)
    return [] if candidates.empty?

    response = client.chat(
      parameters: Prompts::Topic::MatchTalks.new(topic: topic, talks: candidates).to_params,
      resource: topic,
      task_name: "match_talks"
    )

    raw_response = JSON.repair(response.dig("choices", 0, "message", "content"))
    result = JSON.parse(raw_response)

    matching_talk_ids = result["matches"]
      .select { |m| m["matches"] && m["confidence"] == "high" }
      .map { |m| m["talk_id"] }

    candidates.select { |talk| matching_talk_ids.include?(talk.id) }
  rescue => e
    Rails.logger.error "[Topic::Agents] AI filtering failed for topic '#{topic.name}': #{e.message}"
    []
  end

  def client
    @client ||= LLM::Client.new
  end
end
