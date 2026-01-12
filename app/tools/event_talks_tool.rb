# frozen_string_literal: true

class EventTalksTool < RubyLLM::Tool
  description "Get all talks/videos from an event using the Static::Video model. Search by event slug or name."
  param :query, desc: "Event slug (e.g., 'railsconf-2024') or event name (e.g., 'RailsConf 2024')"

  def execute(query:)
    event = Static::Event.find_by_slug(query)
    event ||= Static::Event.all.detect { |e| e.title&.downcase&.include?(query.downcase) }

    return {error: "Event not found for '#{query}'"} if event.nil?

    event_path = File.dirname(event.send(:__file_path))
    videos_file = File.join(event_path, "videos.yml")

    unless File.exist?(videos_file)
      return {error: "No videos.yml found for event '#{event.title}'"}
    end

    videos = Static::Video.all.select do |video|
      video.send(:__file_path) == videos_file
    end

    {
      event_slug: event.slug,
      event_title: event.title,
      event_date: event.start_date&.to_s,
      videos_file: videos_file.sub(Rails.root.to_s + "/", ""),
      talks_count: videos.size,
      talks: videos.map { |video| video_to_hash(video) }
    }
  rescue => e
    {error: e.message}
  end

  private

  def video_to_hash(video)
    {
      title: video.title,
      speakers: video.speakers,
      date: video.date,
      video_provider: video.video_provider,
      video_id: video.video_id,
      published_at: video.published_at,
      description: video.description&.truncate(200)
    }.compact
  end
end
