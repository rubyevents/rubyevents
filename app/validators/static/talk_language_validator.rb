# frozen_string_literal: true

module Static
  # Once some talks of a file set an explicit language, every watchable talk in it does
  #
  class TalkLanguageValidator < ActiveModel::Validator
    def validate(talk)
      return if talk["talks"] || talk["language"].present? || !watchable?(talk)
      return unless file_sets_language?(talk)

      talk.errors.add(:base, %(Other talks in this file already set an explicit "language", so please add one to "#{talk["id"]}" as well, e.g. `language: "English"`, or run `bin/rails talk_languages:backfill` to detect it from the talk's YouTube captions. That way each talk has an explicit language set.), at: "id")
    end

    private

    def file_sets_language?(talk)
      Yerba::Record::Validations.cached(self.class, talk.file_path) do
        talk.file_records.any? { |other| other["language"].present? }
      end
    end

    def watchable?(talk)
      provider = talk["video_provider"]
      provider = talk.parent&.[]("video_provider") if provider == "parent"

      provider.in?(::Talk::WATCHABLE_PROVIDERS)
    end
  end
end
