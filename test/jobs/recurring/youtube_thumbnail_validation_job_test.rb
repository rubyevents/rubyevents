# frozen_string_literal: true

require "test_helper"

class Recurring::YouTubeThumbnailValidationJobTest < ActiveJob::TestCase
  setup do
    @talk = talks(:one)
    @talk.update_columns(video_provider: "youtube", video_id: "dQw4w9WgXcQ", youtube_thumbnail_checked_at: nil)

    Talk.where.not(id: @talk.id).update_all(video_provider: "vimeo")
  end

  test "skips non-YouTube talks" do
    @talk.update_column(:video_provider, "vimeo")

    Recurring::YouTubeThumbnailValidationJob.perform_now

    assert_nil @talk.reload.youtube_thumbnail_checked_at
  end

  test "skips recently checked talks" do
    @talk.update_column(:youtube_thumbnail_checked_at, 1.month.ago)

    Recurring::YouTubeThumbnailValidationJob.perform_now

    # Should not update the timestamp since it was recently checked
    assert @talk.reload.youtube_thumbnail_checked_at < 1.day.ago
  end

  test "rechecks talks older than 3 months" do
    @talk.update_column(:youtube_thumbnail_checked_at, 4.months.ago)

    stub_thumbnail_with_fixture("maxresdefault", 10000, "1920x1080.jpg")

    Recurring::YouTubeThumbnailValidationJob.perform_now

    assert @talk.reload.youtube_thumbnail_checked_at > 1.minute.ago
  end

  test "updates checked_at even when no valid thumbnail found" do
    stub_all_thumbnails_as_default

    Recurring::YouTubeThumbnailValidationJob.perform_now

    assert @talk.reload.youtube_thumbnail_checked_at.present?
  end

  test "prefers 16:9 thumbnail over larger 4:3 thumbnail" do
    stub_thumbnail_as_default("maxresdefault")
    stub_thumbnail_as_default("sddefault")
    stub_thumbnail_as_default("hqdefault")
    stub_thumbnail_with_fixture("mqdefault", 8000, "320x180.jpg")

    Recurring::YouTubeThumbnailValidationJob.perform_now

    assert_equal "https://i.ytimg.com/vi/#{@talk.video_id}/mqdefault.jpg", @talk.reload.thumbnail_xl
  end

  test "falls back to 4:3 thumbnail when no 16:9 available" do
    stub_thumbnail_as_default("maxresdefault")
    stub_thumbnail_as_default("sddefault")
    stub_thumbnail_as_default("mqdefault")
    stub_thumbnail_with_fixture("hqdefault", 13000, "480x360.jpg")
    stub_thumbnail_as_default("default")

    Recurring::YouTubeThumbnailValidationJob.perform_now

    assert_equal "https://i.ytimg.com/vi/#{@talk.video_id}/hqdefault.jpg", @talk.reload.thumbnail_xl
  end

  test "selects largest 16:9 thumbnail available" do
    stub_thumbnail_with_fixture("maxresdefault", 100000, "1920x1080.jpg")
    stub_thumbnail_with_fixture("sddefault", 50000, "640x360.jpg")
    stub_thumbnail_with_fixture("hqdefault", 13000, "480x360.jpg")
    stub_thumbnail_with_fixture("mqdefault", 8000, "320x180.jpg")

    Recurring::YouTubeThumbnailValidationJob.perform_now

    @talk.reload
    assert_equal "https://i.ytimg.com/vi/#{@talk.video_id}/maxresdefault.jpg", @talk.thumbnail_xl
    assert_equal "https://i.ytimg.com/vi/#{@talk.video_id}/sddefault.jpg", @talk.thumbnail_lg
  end

  test "sets thumbnail_lg to best available starting from sddefault" do
    stub_thumbnail_with_fixture("maxresdefault", 100000, "1920x1080.jpg")
    stub_thumbnail_as_default("sddefault")
    stub_thumbnail_with_fixture("hqdefault", 13000, "480x360.jpg")
    stub_thumbnail_with_fixture("mqdefault", 8000, "320x180.jpg")

    Recurring::YouTubeThumbnailValidationJob.perform_now

    @talk.reload

    assert_equal "https://i.ytimg.com/vi/#{@talk.video_id}/maxresdefault.jpg", @talk.thumbnail_xl
    assert_equal "https://i.ytimg.com/vi/#{@talk.video_id}/mqdefault.jpg", @talk.thumbnail_lg
  end

  private

  def stub_all_thumbnails_as_default
    YouTube::Thumbnail::SIZES.each do |size|
      stub_thumbnail_as_default(size)
    end
  end

  def stub_thumbnail_as_default(size)
    url = "https://i.ytimg.com/vi/#{@talk.video_id}/#{size}.jpg"

    stub_request(:head, url).to_return(
      status: 200,
      headers: {"Content-Length" => "1000"}
    )
  end

  def stub_thumbnail_with_fixture(size, content_length, fixture_filename)
    url = "https://i.ytimg.com/vi/#{@talk.video_id}/#{size}.jpg"

    stub_request(:head, url).to_return(
      status: 200,
      headers: {"Content-Length" => content_length.to_s}
    )

    image_body = File.binread(Rails.root.join("test/fixtures/files/thumbnails/#{fixture_filename}"))

    stub_request(:get, url).to_return(
      status: 200,
      body: image_body,
      headers: {"Content-Type" => "image/jpeg"}
    )
  end
end
