# frozen_string_literal: true

module Static
  # A talk without a recording has no video of its own to point at, so its `video_id` is its own `id`
  #
  class TalkVideoIdValidator < ActiveModel::Validator
    PROVIDERS_WITHOUT_RECORDING = %w[not_recorded not_published scheduled].freeze

    def validate(talk)
      return unless mismatched?(talk)

      talk.errors.add(:video_id, %("#{talk["video_id"]}" should be "#{talk["id"]}". A #{talk["video_provider"]} talk uses its own id as its video_id. Run `bin/rails validate:fix` to update it.), at: (talk.key?("video_id") ? "video_id" : "id"))
    end

    def fix(talk)
      return 0 unless mismatched?(talk)

      talk["video_id"] = talk["id"]

      1
    end

    private

    def mismatched?(talk)
      talk["video_provider"].in?(PROVIDERS_WITHOUT_RECORDING) && talk["id"].present? && talk["video_id"] != talk["id"]
    end
  end
end
