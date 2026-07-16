# frozen_string_literal: true

require "generators/event_base"

# Generator for creating a new talk entry in the videos.yml file of a specific event.
class TalkGenerator < Generators::EventBase
  source_root File.expand_path("templates", __dir__)

  class_option :id, type: :string, desc: "ID of an existing talk to update. New talks always get a generated id, so omit this to append one.", required: false, group: "Fields"
  class_option :title, type: :string, desc: "Title of the talk", group: "Fields"
  class_option :original_title, type: :string, desc: "Original title in native language (e.g., Japanese)", required: false, group: "Fields"
  class_option :speakers, type: :array, desc: "Speaker names", group: "Fields"
  class_option :description, type: :string, desc: "Description of the talk", group: "Fields"
  class_option :kind, type: :string, enum: Talk.kinds.keys, desc: "Type of talk (#{Talk.kinds.keys.to_sentence(last_word_connector: " or ")}). Inferred from the title when omitted.", group: "Fields"
  class_option :language, type: :string, desc: "Language of the talk (e.g., 'English', 'Japanese')", group: "Fields"

  # dates
  class_option :date, type: :string, desc: "Date of the talk (YYYY-MM-DD)", required: false, group: "Fields"
  class_option :announced_at, type: :string, desc: "Date when the talk was announced (YYYY-MM-DD)", required: false, group: "Fields"

  # Options
  class_option :lightning_talks, type: :boolean, default: false, desc: "Add empty group of lightning talks", group: "Options"

  # Internal class to represent talk data that defines Defaults
  class Talk
    LIGHTNING_TALKS_DEFAULTS = {
      "title" => "Lightning Talks",
      "kind" => "lightning_talk"
    }.freeze

    attr_accessor :event_slug, :event, :announced_at, :description, :original_title
    attr_writer :id, :date, :language, :speakers, :title, :kind, :existing_ids

    def initialize(**attributes)
      attributes.each { |k, v| send("#{k}=", v) }
    end

    def date
      @date ||= (event&.start_date || Date.today).iso8601
    end

    def id
      @id ||= generate_talk_id
    end

    def event_name
      @event.name
    end

    def language
      @language ||= "English"
    end

    def speakers
      @speakers ||= ["TODO"]
    end

    def title
      @title ||= "#{kind.titlecase} by #{speakers.to_sentence}"
    end

    def kind
      @kind ||= @title.present? ? ::Talk::Kind.from_title(@title).to_s : "talk"
    end

    def write_kind?
      kind != "talk" || ::Talk::Kind.from_title(title).to_s != "talk"
    end

    def generate_talk_id
      candidates = ::Talk::StaticID.new(event_slug: event_slug, title: title, speakers: speakers, kind: kind).candidates

      candidates.find { |candidate| existing_ids.exclude?(candidate) } || candidates.last
    end

    def existing_ids
      @existing_ids || []
    end
  end

  def initialize_values
    @attributes = options.slice(*VideoSchema.properties.keys.map(&:to_s)).compact

    attrs = @attributes.merge({
      event: static_event,
      event_slug: options[:event],
      existing_ids: existing_ids
    })

    attrs = Talk::LIGHTNING_TALKS_DEFAULTS.merge(attrs) if options[:lightning_talks]

    @talk = Talk.new(**attrs)
  end

  def videos_file_path
    @videos_file_path ||= File.join(event_directory, "videos.yml")
  end

  def ensure_file_exists
    template "videos.yml.tt", videos_file_path unless File.exist?(videos_file_path)
  end

  def add_talk_to_file
    gsub_file videos_file_path, /---\s*\[\]\n/, "---\n"

    if File.read(videos_file_path).match?(/- id: "#{Regexp.escape(@talk.id)}"/)
      say("Existing talk with id:'#{@talk.id}' found. Updating...", :yellow)
      update_talk
    elsif options[:id]
      raise Thor::Error, missing_talk_message
    else
      talk_template = options[:lightning_talks] ? "lightning_talks.yml.tt" : "talk.yml.tt"
      say("Appending new talk with id:'#{@talk.id}'...", :green)
      append_to_file videos_file_path, template_content(talk_template)
    end
  end

  private

  def videos_file
    Static::VideosFile.new(videos_file_path) if File.exist?(videos_file_path)
  end

  def existing_ids
    return [] unless videos_file

    videos_file.ids + videos_file.old_ids
  end

  def missing_talk_message
    ids = videos_file&.ids || []

    message = "No talk with id '#{options[:id]}' found in #{videos_file_path}. "
    message << "Available ids:\n  #{ids.join("\n  ")}\n" if ids.any?
    message << "If you are looking to add a new talk, omit --id and an id will be generated for you."
  end

  def update_talk
    document = Static::VideosFile.new(videos_file_path)
    @existing_talk = document.find_by(id: @talk.id)

    @attributes.each do |key, value|
      @existing_talk[key] = value
    end

    document.save!

    say("#{@attributes.keys.to_sentence} updated.", :green)
  end
end
