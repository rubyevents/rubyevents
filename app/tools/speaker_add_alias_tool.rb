# frozen_string_literal: true

class SpeakerAddAliasTool < RubyLLM::Tool
  include SpeakersFileCheck

  description "Add an alias (alternative name) for a speaker in data/speakers.yml. Aliases allow speakers to be found by different names or slugs. Use speaker_lookup first to find the speaker."

  parameter :name, description: "Exact speaker name to find (must match exactly)"
  parameter :alias_name, description: "The alternative name for this speaker"
  parameter :alias_slug, description: "URL-friendly slug for the alias (auto-generated from alias_name if not provided)", required: false

  def execute(name:, alias_name:, alias_slug: nil)
    speaker = speakers.find_by(name: name)

    return {error: "Speaker '#{name}' not found in speakers.yml"} unless speaker

    slug = (alias_slug || alias_name.parameterize).to_s

    existing_aliases = Array(speaker["aliases"])
    if existing_aliases.any? { |a| a["slug"] == slug }
      return {error: "Alias with slug '#{slug}' already exists for #{name}"}
    end

    if existing_aliases.any? { |a| a["name"] == alias_name }
      return {error: "Alias with name '#{alias_name}' already exists for #{name}"}
    end

    speaker.add_alias(name: alias_name, slug: slug)

    speakers.save!

    check_speakers_file({
      success: true,
      speaker: name,
      alias_added: {name: alias_name, slug: slug},
      total_aliases: (existing_aliases.size + 1),
      file: speakers.relative_path
    })
  rescue => e
    {error: e.message}
  end
end
