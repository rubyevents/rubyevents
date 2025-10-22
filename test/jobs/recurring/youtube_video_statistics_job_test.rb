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

  test "should process multiple batches of talks" do
    talks = rand(200).times.map do
      talk = talks(:one).dup
      talk.save!

      assert_not talk.view_count.positive?
      assert_not talk.like_count.positive?
      talk
    end

    Recurring::YouTubeVideoStatisticsJob.perform_later

    VCR.use_cassette("recurring_youtube_statistics_job_multiple_batches", match_requests_on: [:method]) do
      perform_enqueued_jobs

      # Verify all talks were processed
      talks.each do |talk|
        talk.reload
        assert talk.view_count.positive?, "Talk #{talk.id} should have view count"
        assert talk.like_count.positive?, "Talk #{talk.id} should have like count"
      end
    end
  end
end