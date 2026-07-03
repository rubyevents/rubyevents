# frozen_string_literal: true

class SpeakerCreateTool < RubyLLM::Tool
  include SpeakersFileCheck

  description "Add a new speaker to data/speakers.yml. Use speaker_lookup first to verify the speaker doesn't already exist."

  param :name, desc: "Full name of the speaker (if omitted, fetched from GitHub profile)", required: false
  param :github, desc: "GitHub username (not a URL). If name is omitted, the GitHub profile name is used.", required: false
  param :twitter, desc: "Twitter/X handle (without @, not a URL)", required: false
  param :linkedin, desc: "LinkedIn username (the part after /in/, not a URL)", required: false
  param :website, desc: "Personal website URL", required: false
  param :mastodon, desc: "Full Mastodon profile URL (e.g. https://ruby.social/@username)", required: false
  param :bluesky, desc: "Bluesky handle (not a URL)", required: false
  param :speakerdeck, desc: "Speakerdeck username (not a URL)", required: false
  param :slug, desc: "URL-friendly slug (auto-generated from name if not provided)", required: false

  def execute(name: nil, slug: nil, github: nil, **fields)
    return {error: "Provide at least a name or a github handle"} if name.blank? && github.blank?

    if name.blank? && github.present?
      profile = GitHub::UserClient.new.profile(github)
      return {error: "GitHub user '#{github}' not found"} unless profile

      name = profile["name"].presence || github
    end

    if speakers_file.find_by(name: name)
      return {error: "Speaker '#{name}' already exists in speakers.yml"}
    end

    slug = (slug || name.parameterize).to_s

    if speakers_file.index_by(:slug)[slug]
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
    speakers_file.add(name: name, github: github.to_s, slug: slug, **attributes)
    speakers_file.save!

    check_speakers_file({
      success: true,
      speaker: name,
      slug: slug,
      github: github.to_s,
      file: Static::SpeakersFile::SPEAKERS_PATH
    })
  rescue => e
    {error: e.message}
  end
end
