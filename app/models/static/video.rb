module Static
  class Video < FrozenRecord::Base
    self.backend = Backends::MultiFileBackend.new("**/**/videos.yml")
    self.base_path = Rails.root.join("data")

    def self.child_talks
      @child_talks ||= Static::Video.all.flat_map(&:talks).compact
    end

    def self.child_talks_map
      @child_talks_map ||= child_talks.to_h { |talk| [talk.id, talk] }
    end

    def self.all_talks
      @all_talks ||= Static::Video.all + child_talks
    end

    def self.all_talks_map
      @child_talks_map ||= all_talks.to_h { |talk| [talk.id, talk] }
    end

    def self.find_child_talk_by_id(id)
      child_talks_map[id]
    end

    def self.find_by_static_id(id)
      all_talks_map[id]
    end

    def self.import_all!
      all.each(&:import!)
    end

    def raw_title
      super || title
    end

    def description
      super || ""
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

    def speakers
      return [] if self["speakers"].blank?

      super
    end

    def talks
      @talks ||= begin
        return [] if self["talks"].blank?

        super.map { |talk| Static::Video.new(talk) }
      end
    end

    def meta_talk?
      attributes.key?("talks")
    end

    def import!(event: nil, parent_talk: nil)
      if title.blank?
        puts "Ignored video: #{raw_title}"
        return nil
      end

      event ||= find_event

      raise "Event not found for video #{id}" unless event

      talk = ::Talk.find_or_initialize_by(static_id: id)
      talk.parent_talk = parent_talk if parent_talk
      talk.update_from_yml_metadata!(event: event)

      talks.each do |child_video|
        child_video.import!(event: event, parent_talk: talk)
      end

      talk
    rescue ActiveRecord::RecordInvalid => e
      puts "Couldn't save: #{title} (#{id}), error: #{e.message}"
      nil
    end

    def find_event
      return nil unless __file_path

      event_slug = __file_path.split("/")[-2]
      ::Event.find_by(slug: event_slug)
    end

    def __file_path
      attributes["__file_path"]
    end
  end
end
