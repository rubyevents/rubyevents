module Static
  class Video < FrozenRecord::Base
    self.backend = Backends::MultiFileBackend.new("**/**/videos.yml")
    self.base_path = Rails.root.join("data")

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
      talks.any?
    end
  end
end
