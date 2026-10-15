# frozen_string_literal: true

class SpeakerAddAliasTool < RubyLLM::Tool
  include SpeakersFileCheck

  description "Add an alias (alternative name) for a speaker in data/speakers.yml. Aliases allow speakers to be found by different names. Use speaker_lookup first to find the speaker."

  parameter :name, description: "Exact speaker name to find (must match exactly)"
  parameter :alias_name, description: "The alternative name for this speaker"

  def execute(name:, alias_name:)
    speaker = speakers.find_by(name: name)

    return {error: "Speaker '#{name}' not found in speakers.yml"} unless speaker

    if [speaker.name, *speaker.alias_names].any? { |existing| existing.strip.casecmp?(alias_name.strip) }
      return {error: "Alias '#{alias_name}' already exists for #{name}"}
    end

    speaker.add_alias(name: alias_name)
    total_aliases = speaker.alias_names.size

    speakers.save!

    check_speakers_file({
      success: true,
      speaker: name,
      alias_added: alias_name,
      total_aliases: total_aliases,
      file: speakers.relative_path
    })
  rescue => e
    {error: e.message}
  end
end
