# frozen_string_literal: true

class Recurring::YouTubeVideoAvailabilityJob < ApplicationJob
  include ActiveJob::Continuable

  queue_as :low

  RECHECK_INTERVAL = 1.month

  def perform
    step(:check_availability) do |step|
      talks_to_check.find_each(start: step.cursor) do |talk|
        talk.check_video_availability!
        step.advance! from: talk.id
      rescue => e
        Rails.logger.error("Error checking availability for talk #{talk.id}: #{e.message}")
        step.advance! from: talk.id
      end
    end
  end

  private

  def talks_to_check
    Talk.youtube.where(
      "video_availability_checked_at IS NULL OR video_availability_checked_at < ?",
      RECHECK_INTERVAL.ago
    )
  end
end
