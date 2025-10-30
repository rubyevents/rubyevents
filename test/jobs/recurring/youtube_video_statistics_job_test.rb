require "test_helper"
require "minitest/mock"

class Recurring::YouTubeVideoStatisticsJobTest < ActiveJob::TestCase
  DUMMY_VIEW_COUNT = 1000
  DUMMY_LIKE_COUNT = 1000

  test "should update view_count and like_count for youtube talks" do
    VCR.use_cassette("recurring/youtube_statistics_job", match_requests_on: [:method]) do
      talk = talks(:one)

      assert_not talk.view_count.positive?
      assert_not talk.like_count.positive?

      Recurring::YouTubeVideoStatisticsJob.new.perform

      assert talk.reload.view_count.positive?
      assert talk.like_count.positive?
    end
  end

  test "should process multiple batches of talks" do
    talk_count = rand(1..100)
    created_talks = []

    Talk.transaction do
      talk_count.times do
        talk = talks(:one).dup
        talk.save!
        created_talks << talk
      end
    end

    # Verify initial state
    created_talks.each do |talk|
      assert talk.view_count.zero?, "Talk #{talk.id} should start with zero views"
      assert talk.like_count.zero?, "Talk #{talk.id} should start with zero likes"
    end

    # Create a stub client that responds to get_statistics
    stub_client = Object.new
    stub_client.define_singleton_method(:get_statistics) do |video_ids|
      video_ids.each_with_object({}) do |video_id, hash|
        hash[video_id] = {view_count: DUMMY_VIEW_COUNT, like_count: DUMMY_LIKE_COUNT}
      end
    end

    # Stub YouTube::Video.new to return our stub client
    YouTube::Video.stub :new, stub_client do
      Recurring::YouTubeVideoStatisticsJob.perform_later
      perform_enqueued_jobs
    end

    # Verify updated state
    created_talks.each(&:reload)
    created_talks.each do |talk|
      assert_equal DUMMY_VIEW_COUNT, talk.view_count, "Talk #{talk.id} should have #{DUMMY_VIEW_COUNT} views"
      assert_equal 1000, talk.like_count, "Talk #{talk.id} should have #{DUMMY_LIKE_COUNT} likes"
    end
  end
end
