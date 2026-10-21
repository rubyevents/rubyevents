# frozen_string_literal: true

module Static
  class DuplicateYouTubeChannelsValidator < ActiveModel::EachValidator
    def validate_each(event, attribute, channels)
      series_ids = Array(event.series&.[]("youtube_channels")).map { |channel| channel["id"] }.to_set
      return if series_ids.empty?

      Array(channels).each_with_index do |channel, index|
        next unless channel.is_a?(Hash) && series_ids.include?(channel["id"])

        event.errors.add(attribute, %(contains channel "#{channel["id"]}" (#{channel["name"] || "unknown"}) which is already defined in series.yml — remove it from event.yml), at: "#{attribute}[#{index}]")
      end
    end
  end
end
