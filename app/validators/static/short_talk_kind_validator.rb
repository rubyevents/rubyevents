# frozen_string_literal: true

module Static
  # Segments under 10 minutes are usually not regular talks, so they set a kind explicitly
  #
  class ShortTalkKindValidator < ActiveModel::Validator
    SHORT_DURATION_THRESHOLD = 10.minutes.to_i

    def self.short?(talk)
      duration = duration_in_seconds(talk)

      duration && duration < SHORT_DURATION_THRESHOLD
    end

    def self.duration_in_seconds(talk)
      start_seconds = cue_to_seconds(talk["start_cue"])
      end_seconds = cue_to_seconds(talk["end_cue"])
      return nil if start_seconds.nil? || end_seconds.nil?

      duration = end_seconds - start_seconds
      duration.positive? ? duration : nil
    end

    def self.cue_to_seconds(cue)
      cue = cue.to_s.strip
      return nil if cue.empty? || cue == "TODO"
      return nil unless cue.match?(/\A\d+(:\d+)*\z/)

      cue.split(":").map(&:to_i).reverse.each_with_index.reduce(0) { |sum, (value, index)| sum + value * (60**index) }
    end

    def validate(talk)
      return unless talk["kind"].to_s.strip.empty? && self.class.short?(talk)

      formatted = Duration.seconds_to_formatted_duration(self.class.duration_in_seconds(talk), raise: false)

      talk.errors.add(:base, "is only #{formatted} long (under 10 minutes) but has no explicit kind. Short segments are usually not regular talks. Add a `kind` (#{::Talk.kinds.keys}) to classify it, or set `kind: \"talk\"` if it really is a short talk.", at: talk.key?("start_cue") ? "start_cue" : "title")
    end
  end
end
