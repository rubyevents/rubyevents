# frozen_string_literal: true

require "test_helper"

class Recurring::YouTubeVideoAvailabilityJobTest < ActiveJob::TestCase
  setup do
    @talk = talks(:one)
    @talk.update_columns(
      video_provider: "youtube",
      video_id: "dQw4w9WgXcQ",
      video_availability_checked_at: nil,
      video_unavailable_at: nil
    )

    # Make sure other talks don't interfere
    Talk.where.not(id: @talk.id).update_all(video_provider: "vimeo")
  end

  test "skips non-YouTube talks" do
    @talk.update_column(:video_provider, "vimeo")

    Recurring::YouTubeVideoAvailabilityJob.perform_now

    assert_nil @talk.reload.video_availability_checked_at
  end

  test "skips recently checked talks" do
    @talk.update_column(:video_availability_checked_at, 1.week.ago)

    Recurring::YouTubeVideoAvailabilityJob.perform_now

    # Should not update the timestamp since it was recently checked
    assert @talk.reload.video_availability_checked_at < 1.day.ago
  end

  test "rechecks talks older than 1 month" do
    @talk.update_column(:video_availability_checked_at, 2.months.ago)

    stub_video_available

    Recurring::YouTubeVideoAvailabilityJob.perform_now

    assert @talk.reload.video_availability_checked_at > 1.minute.ago
  end

  test "marks video as available when API returns data" do
    @talk.update_column(:video_unavailable_at, 1.week.ago)

    stub_video_available

    Recurring::YouTubeVideoAvailabilityJob.perform_now

    @talk.reload
    assert_nil @talk.video_unavailable_at
    assert @talk.video_availability_checked_at.present?
  end

  test "marks video as unavailable when API returns no data" do
    stub_video_unavailable

    Recurring::YouTubeVideoAvailabilityJob.perform_now

    @talk.reload
    assert @talk.video_unavailable_at.present?
    assert @talk.video_availability_checked_at.present?
  end

  test "preserves original unavailable_at timestamp on subsequent checks" do
    original_time = 1.week.ago
    @talk.update_columns(video_unavailable_at: original_time, video_availability_checked_at: 2.months.ago)

    stub_video_unavailable

    Recurring::YouTubeVideoAvailabilityJob.perform_now

    @talk.reload
    assert_in_delta original_time, @talk.video_unavailable_at, 1.second
  end

  private

  def stub_video_available
    stub_request(:get, %r{youtube\.googleapis\.com/youtube/v3/videos})
      .to_return(
        status: 200,
        body: {items: [{id: @talk.video_id, status: {privacyStatus: "public"}}]}.to_json,
        headers: {"Content-Type" => "application/json"}
      )
  end

  def stub_video_unavailable
    stub_request(:get, %r{youtube\.googleapis\.com/youtube/v3/videos})
      .to_return(
        status: 200,
        body: {items: []}.to_json,
        headers: {"Content-Type" => "application/json"}
      )
  end
end
