# frozen_string_literal: true

require "generators/event_base"

class TalkGenerator < Generators::EventBase
  source_root File.expand_path("templates", __dir__)

  class_option :id, type: :string, desc: "ID of the talk (optional, will be generated from title and speaker if not provided)", required: false, group: "Fields"
  class_option :title, type: :string, desc: "Title of the talk", group: "Fields"
  class_option :speaker, type: :array, default: ["TODO"], desc: "Speaker name", group: "Fields"
  class_option :description, type: :string, default: "TODO - description", desc: "Description of the talk", group: "Fields"
  class_option :kind, type: :string, enum: Talk.kinds.keys, default: "talk", desc: "Type of talk (e.g., 'keynote', 'lightning_talk')", group: "Fields"
  class_option :language, type: :string, default: "en", desc: "Language of the talk (e.g., 'en', 'es')", group: "Fields"

  # dates
  class_option :date, type: :string, desc: "Date of the talk (YYYY-MM-DD)", required: false, group: "Fields"
  class_option :announced_at, type: :string, desc: "Date when the talk was announced (YYYY-MM-DD)", required: false, group: "Fields"

  class_option :lightning_talks, type: :boolean, default: false, desc: "Add empty group of lightning talks", group: "Options"

  Talk = Struct.new(:id, :title, :speakers, :description, :kind, :language, :date, :announced_at) do
    def title
      @title ||= self[:title].presence || ["TODO", options[:kind], "Title"].merge(options[:speakers]).compact.join(" ")
    end

    def description
      @description ||= self[:description].presence || ["TODO", options[:title], "Description"].merge(options[:speakers]).compact.join(" ")
    end

    def talk_id
      @talk_id ||= options[:id].presence || generate_talk_id
    end
  end

  def initialize_values
    event = Static::Event.find_by_slug options[:event]
    @date = options[:date] || (event&.start_date || Date.today).iso8601
  end

  def videos_file_path
    @videos_file_path ||= File.join(event_directory, "videos.yml")
  end

  def add_talk_to_file
    template "videos.yml.tt", videos_file_path unless File.exist?(videos_file_path)
    talk_template = options[:lightning_talks] ? "lightning_talks.yml.tt" : "talk.yml.tt"

    if File.read(videos_file_path).match?(/- id: "#{talk_id}"/)
      match_one_talk = /\n- id: "#{talk_id}"[\s\S]*video_id: "#{talk_id}"\n/
      gsub_file videos_file_path, match_one_talk, template_content(talk_template)
    else
      append_to_file videos_file_path, template_content(talk_template)
    end
  end

  private

  def generate_talk_id
    talk_id_parts = []
    if options[:speaker].length > 2
      talk_id_parts << options[:title].parameterize
    else
      talk_id_parts.concat(options[:speaker].map(&:parameterize))
    end
    talk_id_parts << options[:kind] unless options[:kind].in? ["talk", "panel"]
    talk_id_parts << options[:event]
    talk_id_parts.join("-")
  end
end
