# frozen_string_literal: true

require "generators/event_base"

class TalkGenerator < Generators::EventBase
  source_root File.expand_path("templates", __dir__)

  class_option :id, type: :string, desc: "ID of the talk (optional, will be generated from title and speaker if not provided)", required: false, group: "Fields"
  class_option :title, type: :string, desc: "Title of the talk", group: "Fields"
  class_option :speakers, type: :array, default: ["TODO"], desc: "Speaker names", group: "Fields"
  class_option :description, type: :string, desc: "Description of the talk", group: "Fields"
  class_option :kind, type: :string, enum: Talk.kinds.keys, default: "talk", desc: "Type of talk (e.g., 'keynote', 'lightning_talk')", group: "Fields"
  class_option :language, type: :string, default: "en", desc: "Language of the talk (e.g., 'en', 'es')", group: "Fields"

  # dates
  class_option :date, type: :string, desc: "Date of the talk (YYYY-MM-DD)", required: false, group: "Fields"
  class_option :announced_at, type: :string, desc: "Date when the talk was announced (YYYY-MM-DD)", required: false, group: "Fields"

  # Options
  class_option :lightning_talks, type: :boolean, default: false, desc: "Add empty group of lightning talks", group: "Options"

  class Talk
    attr_accessor :event_slug, :event, :announced_at, :kind, :language, :speakers
    attr_writer :id, :title, :date, :description

    def initialize(**attributes)
      attributes.each { |k, v| send("#{k}=", v) }
    end

    def title
      @title ||= "#{kind.titlecase} by #{speakers.to_sentence}"
    end

    def date
      @date ||= (event&.start_date || Date.today).iso8601
    end

    def description
      @description ||= ["TODO", title, "Description"].join(" - ")
    end

    def id
      @id ||= generate_talk_id
    end

    def event_name
      @event.name
    end

    def generate_talk_id
      talk_id_parts = []
      if speakers.length > 2 || speakers.length.zero?
        talk_id_parts << title.parameterize
      else
        talk_id_parts.concat(speakers.map(&:parameterize))
      end
      talk_id_parts << kind unless kind.in? ["talk", "panel"]
      talk_id_parts << event_slug
      talk_id_parts.join("-")
    end
  end

  class LightningTalk < Talk
    def id
      @id ||= "lightning-talks-#{event_slug}"
    end

    def title
      @title ||= "Lightning Talks"
    end

    def description
      @description ||= "Lightning talks."
    end
  end

  def initialize_values
    attributes = options
      .slice(*VideoSchema.properties.keys)
      .merge({
        event: static_event,
        event_slug: options[:event]
      })
    @talk = options[:lightning_talks] ? LightningTalk.new(**attributes) : Talk.new(**attributes)
  end

  def videos_file_path
    @videos_file_path ||= File.join(event_directory, "videos.yml")
  end

  def add_talk_to_file
    template "videos.yml.tt", videos_file_path unless File.exist?(videos_file_path)
    talk_template = options[:lightning_talks] ? "lightning_talks.yml.tt" : "talk.yml.tt"

    if File.read(videos_file_path).match?(/- id: "#{@talk.id}"/)
      match_one_talk = /\n- id: "#{@talk.id}"[\s\S]*video_id: "#{@talk.id}"\n/
      gsub_file videos_file_path, match_one_talk, template_content(talk_template)
    else
      append_to_file videos_file_path, template_content(talk_template)
    end
  end
end
