# frozen_string_literal: true

module Static
  class Talk < Yerba::Record::Base
    self.glob = "**/videos.yml"
    self.base_path = Rails.root.join("data")
    self.flatten = true

    schema VideoSchema

    belongs_to :event

    has_one :series, through: :event

    references :speakers

    SEARCH_INDEX_ON_IMPORT_DEFAULT = ENV.fetch("SEARCH_INDEX_ON_IMPORT", "true") == "true"

    class << self
      def child_talks
        @child_talks ||= all.flat_map(&:talks).compact
      end

      def child_talks_map
        @child_talks_map ||= child_talks.to_h { |talk| [talk.id, talk] }
      end

      def all_talks
        @all_talks ||= all.to_a + child_talks
      end

      def all_talks_map
        @all_talks_map ||= all_talks.to_h { |talk| [talk.id, talk] }
      end

      def find_child_talk_by_id(id)
        child_talks_map[id]
      end

      def find_by_static_id(id)
        all_talks_map[id]
      end

      def where_event_slug(event_slug)
        all.select { |video| video.relative_file_path&.include?("/#{event_slug}/") }
      end

      def import_all!(index: SEARCH_INDEX_ON_IMPORT_DEFAULT)
        all.each { |video| video.import!(index: index) }
      end

      def unload!
        super

        @child_talks = nil
        @child_talks_map = nil
        @all_talks = nil
        @all_talks_map = nil
      end
    end

    def raw_title
      self["raw_title"] || title
    end

    def description
      self["description"] || ""
    end

    def start_cue
      self["start_cue"]
    end

    def end_cue
      self["end_cue"]
    end

    def thumbnail_cue
      duration_to_formatted_cue(ActiveSupport::Duration.build(thumbnail_cue_in_seconds))
    end

    def duration_fs
      duration_to_formatted_cue(duration)
    end

    def duration_to_formatted_cue(duration)
      Duration.seconds_to_formatted_duration(duration)
    end

    def duration
      ActiveSupport::Duration.build(duration_in_seconds)
    end

    def duration_in_seconds
      end_cue_in_seconds - start_cue_in_seconds
    end

    def start_cue_in_seconds
      convert_cue_to_seconds(start_cue)
    end

    def end_cue_in_seconds
      convert_cue_to_seconds(end_cue)
    end

    def thumbnail_cue_in_seconds
      (self["thumbnail_cue"] && self["thumbnail_cue"] != "TODO") ? convert_cue_to_seconds(self["thumbnail_cue"]) : (start_cue_in_seconds + 5)
    end

    def convert_cue_to_seconds(cue)
      return nil if cue.blank?

      cue.split(":").map(&:to_i).reverse.each_with_index.reduce(0) do |sum, (value, index)|
        sum + value * 60**index
      end
    end

    def talks
      @talks ||= begin
        talk_data = self["talks"]
        return [] if talk_data.blank?

        Array(talk_data).filter_map do |talk|
          Static::Talk.new(talk.freeze, file_path: file_path)
        rescue Yerba::ParseError
          nil
        end
      end
    end

    def meta_talk?
      self["talks"].present?
    end

    def import!(event: nil, parent_talk: nil, index: SEARCH_INDEX_ON_IMPORT_DEFAULT)
      if title.blank?
        puts "Ignored video: #{raw_title}"
        return nil
      end

      event ||= self.event&.event_record

      raise "Event not found for video #{id}" unless event

      talk = ::Talk.find_or_initialize_by(static_id: id)
      talk.parent_talk = parent_talk if parent_talk
      talk.update_from_yml_metadata!(event: event)

      Search::Backend.index(talk) if index

      talks.each do |child_video|
        child_video.import!(event: event, parent_talk: talk, index: index)
      end

      talk
    rescue ActiveRecord::RecordInvalid => e
      puts "Couldn't save: #{title} (#{id}), error: #{e.message}"
      nil
    end
  end
end
