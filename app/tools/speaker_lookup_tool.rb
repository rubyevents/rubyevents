# frozen_string_literal: true

class SpeakerLookupTool < RubyLLM::Tool
  include SpeakersFileCheck

  description "Search for speakers in data/speakers.yml by name, slug, alias, github, or twitter handle. Returns matching speakers with their info."
  parameter :query, description: "Search query (matches against name, slug, github, twitter, aliases, redirect slugs, and additional GitHub handles). Case-insensitive."

  def execute(query:)
    q = query.downcase

    matches = speakers.filter_map do |speaker|
      entry = speaker.to_h

      searchable = [
        entry["name"],
        entry["slug"],
        entry["github"],
        entry["twitter"],
        entry["linkedin"],
        entry["bluesky"],
        entry["speakerdeck"]
      ]

      searchable.concat(Array(entry["aliases"]), Array(entry["slugs"]), Array(entry["github_handles"]))

      next unless searchable.compact.any? { |v| v.to_s.downcase.include?(q) }

      speaker_to_hash(entry, speaker.index)
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

    {aliases: "aliases", slugs: "slugs", github_handles: "github_handles"}.each do |key, field|
      values = Array(entry[field]).compact_blank
      result[key] = values if values.any?
    end

    result
  end
end
