# frozen_string_literal: true

class SpeakerLookupTool < RubyLLM::Tool
  include SpeakersFileCheck

  description "Search for speakers in data/speakers.yml by name, slug, alias, github, or twitter handle. Returns matching speakers with their info."
  param :query, desc: "Search query (matches against name, slug, github, twitter, aliases). Case-insensitive."

  def execute(query:)
    q = query.downcase

    matches = speakers_file.document.value_at("").each_with_index.filter_map do |entry, index|
      next unless entry.is_a?(Hash)

      searchable = [
        entry["name"],
        entry["slug"],
        entry["github"],
        entry["twitter"],
        entry["linkedin"],
        entry["bluesky"],
        entry["speakerdeck"]
      ]

      Array(entry["aliases"]).each do |a|
        searchable << a["name"] if a.is_a?(Hash)
        searchable << a["slug"] if a.is_a?(Hash)
      end

      next unless searchable.compact.any? { |v| v.to_s.downcase.include?(q) }

      speaker_to_hash(entry, index)
    end

    matches.first(25)
  rescue => e
    {error: e.message}
  end

  private

  def speaker_to_hash(entry, index)
    result = {
      index: index,
      name: entry["name"],
      slug: entry["slug"],
      github: entry["github"].presence,
      twitter: entry["twitter"].presence,
      linkedin: entry["linkedin"].presence,
      mastodon: entry["mastodon"].presence,
      bluesky: entry["bluesky"].presence,
      speakerdeck: entry["speakerdeck"].presence,
      website: entry["website"].presence
    }.compact

    aliases = Array(entry["aliases"]).filter_map { |a| a["name"] if a.is_a?(Hash) }
    result[:aliases] = aliases if aliases.any?

    result
  end
end
