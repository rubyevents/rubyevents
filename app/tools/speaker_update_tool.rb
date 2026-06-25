# frozen_string_literal: true

class SpeakerUpdateTool < RubyLLM::Tool
  include SpeakersFileCheck

  description "Update a speaker's profile fields in data/speakers.yml. Use speaker_lookup first to find the speaker. Only provided fields are updated, others are left unchanged. When changing slug, an alias for the old slug is automatically created."

  param :name, desc: "Exact speaker name to find (must match exactly)"
  param :slug, desc: "New URL-friendly slug (automatically creates alias for old slug)", required: false
  param :github, desc: "GitHub username (not a URL)", required: false
  param :twitter, desc: "Twitter/X handle (without @, not a URL)", required: false
  param :linkedin, desc: "LinkedIn username (the part after /in/, not a URL)", required: false
  param :website, desc: "Personal website URL", required: false
  param :mastodon, desc: "Full Mastodon profile URL (e.g. https://ruby.social/@username)", required: false
  param :bluesky, desc: "Bluesky handle (not a URL)", required: false
  param :speakerdeck, desc: "Speakerdeck username (not a URL)", required: false

  UPDATABLE_FIELDS = %w[slug github twitter linkedin website mastodon bluesky speakerdeck].freeze

  def execute(name:, **fields)
    speaker = speakers_file.find_by(name: name)

    return {error: "Speaker '#{name}' not found in speakers.yml"} unless speaker

    index = speakers_file.index_by(:name)[name]
    return {error: "Could not find index for speaker '#{name}'"} unless index

    updates = fields.select { |key, value| UPDATABLE_FIELDS.include?(key.to_s) && !value.nil? }
    return {error: "No fields to update. Provide at least one of: #{UPDATABLE_FIELDS.join(", ")}"} if updates.empty?

    handle_fields = %w[github twitter linkedin bluesky speakerdeck]

    updates.each do |key, value|
      if handle_fields.include?(key.to_s) && value.to_s.include?("://")
        return {error: "#{key} should be a username, not a URL. Got: #{value}"}
      end
    end

    alias_created = false

    if updates[:slug]
      old_slug = speaker["slug"]
      new_slug = updates[:slug].to_s

      if old_slug.present? && old_slug != new_slug
        existing_aliases = speaker["aliases"] || []

        unless existing_aliases.any? { |a| a["slug"] == old_slug }
          alias_entry = {name: name, slug: old_slug}
          speakers_file.document.root[index]["aliases"] = (Array(existing_aliases) + [alias_entry])
          alias_created = true
        end
      end
    end

    updates.each do |key, value|
      speakers_file.document.set("[#{index}].#{key}", value.to_s)
    end

    speakers_file.save!

    result = {
      success: true,
      speaker: name,
      updated_fields: updates.transform_values(&:to_s),
      file: Static::SpeakersFile::SPEAKERS_PATH
    }

    result[:alias_created] = "#{name} (#{old_slug})" if alias_created

    check_speakers_file(result)
  rescue => e
    {error: e.message}
  end
end
