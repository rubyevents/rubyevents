# frozen_string_literal: true

module Static
  class RemovedTalkIdsValidator < ActiveModel::EachValidator
    def validate_each(event, attribute, removed_ids)
      return if removed_ids.blank?

      talks = event.talks
      return unless talks.exist?

      known_ids = (talks.ids + talks.old_ids).to_set

      Array(removed_ids).each_with_index do |id, index|
        next unless known_ids.include?(id)

        event.errors.add(:base, %(id "#{id}" is listed under `removed_talk_ids`, but it is still in videos.yml. Either drop it from `removed_talk_ids`, or remove the talk from videos.yml.), at: "#{attribute}[#{index}]")
      end
    end
  end
end
