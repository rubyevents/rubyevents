# frozen_string_literal: true

class SpeakerCreateTool < RubyLLM::Tool
  include SpeakersFileCheck

  description "Add a new speaker to data/speakers.yml. Use speaker_lookup first to verify the speaker doesn't already exist."

  parameter :name, description: "Full name of the speaker (if omitted, fetched from GitHub profile)", required: false
  parameter :github, description: "GitHub username (not a URL). If name is omitted, the GitHub profile name is used.", required: false
  parameter :twitter, description: "Twitter/X handle (without @, not a URL)", required: false
  parameter :linkedin, description: "LinkedIn username (the part after /in/, not a URL)", required: false
  parameter :website, description: "Personal website URL", required: false
  parameter :mastodon, description: "Full Mastodon profile URL (e.g. https://ruby.social/@username)", required: false
  parameter :bluesky, description: "Bluesky handle (not a URL)", required: false
  parameter :speakerdeck, description: "Speakerdeck username (not a URL)", required: false

  def execute(name: nil, github: nil, **fields)
    return {error: "Provide at least a name or a github handle"} if name.blank? && github.blank?

    if name.blank? && github.present?
      profile = GitHub::UserClient.new.profile(github)
      return {error: "GitHub user '#{github}' not found"} unless profile

      name = profile["name"].presence || github
    end

    aliases = []

    if name.parameterize.empty?
      return {error: "Speaker name '#{name}' cannot be turned into a slug. Provide a romanized name, or a GitHub handle to use as the name."} if github.blank?

      aliases << name
      name = github
    end

    if speakers.find_by(name: name)
      return {error: "Speaker '#{name}' already exists in speakers.yml"}
    end

    slug = name.parameterize

    if speakers.find_by(slug: slug)
      return {error: "A speaker with slug '#{slug}' already exists in speakers.yml"}
    end

    handle_fields = %w[twitter linkedin bluesky speakerdeck]

    fields.each do |key, value|
      next if value.nil?

      if handle_fields.include?(key.to_s) && value.to_s.include?("://")
        return {error: "#{key} should be a username, not a URL. Got: #{value}"}
      end
    end

    if github.to_s.include?("://")
      return {error: "github should be a username, not a URL. Got: #{github}"}
    end

    attributes = fields.reject { |_, v| v.nil? }
    speakers.add(name: name, github: github.to_s, **attributes)
    aliases.each { |alias_name| speakers.find_by(name: name).add_alias(name: alias_name) }
    speakers.save!

    check_speakers_file({
      success: true,
      speaker: name,
      slug: slug,
      github: github.to_s,
      aliases: aliases.presence,
      file: speakers.relative_path
    })
  rescue => e
    {error: e.message}
  end
end
