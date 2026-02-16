# frozen_string_literal: true

require "generators/event_base"

class TalkGenerator < Generators::EventBase
  source_root File.expand_path("templates", __dir__)

  class_option :title, type: :string, default: "TODO", desc: "Title of the talk"
  class_option :speaker, type: :array, default: ["TODO"], desc: "Speaker name"
  class_option :description, type: :string, default: "TODO", desc: "Description of the talk"
  class_option :date, type: :string, desc: "Date of the talk (YYYY-MM-DD)", required: false
  class_option :kind, type: :string, enum: Talk.kinds.keys, default: "talk", desc: "Type of talk (e.g., 'keynote', 'lightning')"

  def initialize_values
    event = Static::Event.find_by_slug options[:event]
    @date = options[:date] || (event&.start_date || Date.today).iso8601
    @talk_id = "#{options[:speaker].first.parameterize}-#{options[:kind]}-#{options[:event]}"
  end

  def add_talk_to_file
    videos_file_path = File.join("data", options[:event_series], options[:event], "videos.yml")
    template "videos.yml.tt", videos_file_path unless File.exist? videos_file_path

    if File.read(destination_path(videos_file_path)).match?(/- id: "#{@talk_id}"/)
      match_one_talk = /\n- id: "#{@talk_id}"[\s\S]*video_id: "#{@talk_id}"/
      gsub_file videos_file_path, match_one_talk, template_content("talk.yml.tt")
    else
      append_to_file videos_file_path, template_content("talk.yml.tt")
    end
  end
end
