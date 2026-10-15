# frozen_string_literal: true

class SpeakerUpdateTool < RubyLLM::Tool
  include SpeakersFileCheck

  description "Update a speaker's profile fields in data/speakers.yml. Use speaker_lookup first to find the speaker. Only provided fields are updated, others are left unchanged. When changing slug, the old slug is automatically added to slugs so it keeps redirecting."

  parameter :name, description: "Exact speaker name to find (must match exactly)"
  parameter :slug, description: "New URL-friendly slug (the old slug is added to slugs so it keeps redirecting)", required: false
  parameter :github, description: "GitHub username (not a URL)", required: false
  parameter :twitter, description: "Twitter/X handle (without @, not a URL)", required: false
  parameter :linkedin, description: "LinkedIn username (the part after /in/, not a URL)", required: false
  parameter :website, description: "Personal website URL", required: false
  parameter :mastodon, description: "Full Mastodon profile URL (e.g. https://ruby.social/@username)", required: false
  parameter :bluesky, description: "Bluesky handle (not a URL)", required: false
  parameter :speakerdeck, description: "Speakerdeck username (not a URL)", required: false

  UPDATABLE_FIELDS = %w[slug github twitter linkedin website mastodon bluesky speakerdeck].freeze

  def execute(name:, **fields)
    speaker = speakers.find_by(name: name)

    return {error: "Speaker '#{name}' not found in speakers.yml"} unless speaker

    updates = fields.select { |key, value| UPDATABLE_FIELDS.include?(key.to_s) && !value.nil? }
    return {error: "No fields to update. Provide at least one of: #{UPDATABLE_FIELDS.join(", ")}"} if updates.empty?

    handle_fields = %w[github twitter linkedin bluesky speakerdeck]

    updates.each do |key, value|
      if handle_fields.include?(key.to_s) && value.to_s.include?("://")
        return {error: "#{key} should be a username, not a URL. Got: #{value}"}
      end
    end

    redirect_slug_added = false

    if updates[:slug]
      old_slug = speaker["slug"]
      new_slug = updates[:slug].to_s

      if old_slug.present? && old_slug != new_slug && speaker.redirect_slugs.exclude?(old_slug)
        speaker.add_slug(old_slug)
        redirect_slug_added = true
      end
    end

    updates.each do |key, value|
      speaker[key] = value.to_s
    end

    speakers.save!

    result = {
      success: true,
      speaker: name,
      updated_fields: updates.transform_values(&:to_s),
      file: speakers.relative_path
    }

    result[:redirect_slug_added] = old_slug if redirect_slug_added

    check_speakers_file(result)
  rescue => e
    {error: e.message}
  end
end
