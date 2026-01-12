require "test_helper"

class Recurring::YouTubeVideoStatisticsJobTest < ActiveJob::TestCase
  test "should update view_count and like_count for youtube talks" do
    VCR.use_cassette("recurring_youtube_statistics_job", match_requests_on: [:method]) do
      talk = talks(:one)

      assert_not talk.view_count.positive?
      assert_not talk.like_count.positive?

      Recurring::YouTubeVideoStatisticsJob.new.perform

      assert talk.reload.view_count.positive?
      assert talk.like_count.positive?
    end
  end
end
