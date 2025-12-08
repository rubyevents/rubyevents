class Recurring::YouTubeVideoStatisticsJob < ApplicationJob
  queue_as :low

  def perform
    Talk.youtube.in_batches(of: 50) do |talks|
      stats = YouTube::Video.new.get_statistics(talks.pluck(:video_id))
      talks.each do |talk|
        if stats[talk.video_id]
          talk.update!(view_count: stats[talk.video_id][:view_count], like_count: stats[talk.video_id][:like_count])
        end
      end
    end
  end
end
