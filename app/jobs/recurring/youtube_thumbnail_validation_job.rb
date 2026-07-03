# frozen_string_literal: true

class Recurring::YouTubeThumbnailValidationJob < ApplicationJob
  include ActiveJob::Continuable

  queue_as :low

  RECHECK_INTERVAL = 3.months

  def perform
    step(:validate_thumbnails) do |step|
      talks_to_check.find_each(start: step.cursor) do |talk|
        validate_thumbnail(talk)
        step.advance! from: talk.id
      rescue => e
        Rails.logger.error("Error validating thumbnail for talk #{talk.id}: #{e.message}")
        step.advance! from: talk.id
      end
    end
  end

  private

  def talks_to_check
    Talk.youtube.where(
      "youtube_thumbnail_checked_at IS NULL OR youtube_thumbnail_checked_at < ?",
      RECHECK_INTERVAL.ago
    )
  end

  def validate_thumbnail(talk)
    thumbnail = YouTube::Thumbnail.new(talk.video_id)

    updates = {youtube_thumbnail_checked_at: Time.current}

    if (xl_url = thumbnail.best_url_for(:thumbnail_xl))
      updates[:thumbnail_xl] = xl_url
    end

    if (lg_url = thumbnail.best_url_for(:thumbnail_lg))
      updates[:thumbnail_lg] = lg_url
    end

    talk.update_columns(updates)
  end
end
