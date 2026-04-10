class Recurring::YouTubeVideoDurationJob < ApplicationJob
  queue_as :low

  def perform
    Talk.youtube.without_duration.find_each do |talk|
      talk.fetch_duration_from_youtube_later!
    end
  end
end
