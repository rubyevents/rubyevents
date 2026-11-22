# frozen_string_literal: true

require "rails/generators"

# Add or update a speaker entry in the global data/speakers.yml file.
#
# Thin wrapper around Static::Speaker#upsert/save!. Supports every social field
# defined in SpeakerSchema (github, twitter, website, mastodon, bluesky,
# linkedin, speakerdeck) plus aliases. speakers.yml is global, so an event is
# not required.
class SpeakerGenerator < Rails::Generators::Base
  TOOL_DESC = "Add or update a speaker in data/speakers.yml."

  class_option :name, type: :string, desc: SpeakerSchema.properties[:name][:description], required: true, group: "Fields"

  # All social fields defined in SpeakerSchema.
  SOCIAL_FIELDS = %i[github twitter website mastodon bluesky linkedin speakerdeck].freeze

  SOCIAL_FIELDS.each do |field|
    class_option field, type: :string, desc: SpeakerSchema.properties[field][:description], required: false, group: "Fields"
  end

  class_option :aliases, type: :array, desc: "Alternative names (aliases) for the speaker", required: false, group: "Fields"

  def add_speaker_to_file
    speakers = Static::Speaker.in_file(speakers_file_path)

    name = options[:name].to_s.strip
    github = options[:github].to_s.strip

    slug = name.parameterize
    slug = github if slug.blank?

    begin
      speaker = speakers.upsert(
        name: name,
        slug: slug,
        **socials
      )

      aliases.each { |alias_data| add_alias(speaker, alias_data) }
    rescue Static::Speaker::InvalidSpeakerError, Static::Speaker::DuplicateSpeakerError => e
      say_error(e.message, :red)
      return
    end

    unless speakers.changed?
      say("#{name} already exists in #{speakers_file_path}; no changes.", :yellow)
      return
    end

    speakers.save!

    speaker = speakers.find_by(name: name)
    say("Added or updated #{speaker["name"]} in #{speakers.relative_path}.", :green)
  end

  private

  def speakers_file_path
    @speakers_file_path ||= File.join(destination_root, "data", "speakers.yml")
  end

  def socials
    @socials ||= SOCIAL_FIELDS.each_with_object({}) do |field, hash|
      value = options[field]
      hash[field] = value if value.present?
    end
  end

  def aliases
    @aliases ||= parse_aliases(options[:aliases])
  end

  def parse_aliases(values)
    return [] if values.blank?

    Array(values).map do |alias_name|
      alias_name = alias_name.to_s.strip
      next if alias_name.blank?

      {"name" => alias_name, "slug" => alias_name.parameterize}
    end.compact
  end

  def add_alias(speaker, alias_data)
    return if alias_exists?(speaker, alias_data)

    speaker.add_alias(name: alias_data["name"], slug: alias_data["slug"])
  end

  def alias_exists?(speaker, alias_data)
    Array(speaker["aliases"]).any? do |existing|
      existing.is_a?(Hash) && (existing["slug"] == alias_data["slug"] || existing["name"] == alias_data["name"])
    end
  end
end
