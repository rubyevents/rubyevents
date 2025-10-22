class Recurring::YouTubeVideoStatisticsJob < ApplicationJob
  include ActiveJob::Continuable

  BATCH_SIZE = 50
  queue_as :low

  def perform
    step :iterate_videos do |step|
      Talk.youtube.in_batches(of: BATCH_SIZE, start: step.cursor) do |talks|
        stats = YouTube::Video.new.get_statistics(talks.pluck(:video_id))
        talks.each do |talk|
          if stats[talk.video_id]
            talk.update!(view_count: stats[talk.video_id][:view_count], like_count: stats[talk.video_id][:like_count])
          end
          step.advance! from: talk.id
        end
      end
    end
  end
end
