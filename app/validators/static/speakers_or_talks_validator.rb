# frozen_string_literal: true

module Static
  class SpeakersOrTalksValidator < ActiveModel::Validator
    def validate(talk)
      has_talks = talk.key?("talks")
      has_speakers = talk.key?("speakers")
      return if has_talks ^ has_speakers

      message = if has_talks
        "an entry must have either `talks` or `speakers`, but not both."
      else
        "an entry must have either `talks` (a container) or `speakers` (a single talk), but has neither."
      end

      talk.errors.add(:base, message, at: %w[talks speakers title].find { |key| talk.key?(key) })
    end
  end
end
