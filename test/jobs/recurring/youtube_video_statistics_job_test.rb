require "test_helper"
require "active_job/continuation/test_helper"
require "helpers/test_logger"


class Recurring::YouTubeVideoStatisticsJobTest < ActiveJob::TestCase
  include ActiveJob::Continuation::TestHelper
  include TestLoggerHelper
  
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
  
  test "resume job after interruption" do
    # test there are 2 batches
    talks = (Recurring::YouTubeVideoStatisticsJob::BATCH_SIZE * 2).times.map do |i|
      talk = talks(:one).dup
      talk.save!
      
      assert_not talk.view_count.positive?
      assert_not talk.like_count.positive?
      talk
    end
    
    Recurring::YouTubeVideoStatisticsJob.perform_later
    
    # test interruption the second batch
    cursor = talks[Recurring::YouTubeVideoStatisticsJob::BATCH_SIZE - 1].id
    interrupt_job_during_step Recurring::YouTubeVideoStatisticsJob, :iterate_videos, cursor: cursor do
      VCR.use_cassette("recurring_youtube_statistics_job_interrupted", match_requests_on: [:method]) do
        perform_enqueued_jobs
      end
      puts @logger.messages
    end
    
    # reload talks to reflect any changes made by the job before interruption
    talks.each(&:reload)
    
    # assert that half the talks have been updated and the other half have not
    processed_talks = talks.select {|talk| talk.view_count.positive? }
    unprocessed_talks = talks.select {|talk| !talk.view_count.positive? }
    
    assert_equal processed_talks.size > 0, true
    assert_equal unprocessed_talks.size > 0, true
    
    VCR.use_cassette("recurring_youtube_statistics_job_successful", match_requests_on: [:method]) do
      # resume the job
      perform_enqueued_jobs
    end
    puts @logger.messages
    
    # reload all talks to reflect changes made by the resumed job
    talks.each(&:reload)
    
    # assert that all talks have been updated
    talks.each do |talk|
      assert talk.view_count.positive?
      assert talk.like_count.positive?
    end
  end
end