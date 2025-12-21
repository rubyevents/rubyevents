# frozen_string_literal: true

class SpeakerTalksTool < RubyLLM::Tool
  description "Get all talks from a speaker by their name, slug, or ID."
  param :name, desc: "Speaker name or slug to lookup (e.g., 'Aaron Patterson' or 'tenderlove')", required: false
  param :id, desc: "Speaker ID in the database", required: false

  def execute(name: nil, id: nil)
    user = find_user(name: name, id: id)

    return {error: "User not found"} if user.nil?

    talks = user.talks.includes(:event).order(date: :desc)

    {
      user_id: user.id,
      user_name: user.name,
      user_slug: user.slug,
      talks_count: talks.size,
      talks: talks.map { |talk| talk_to_hash(talk) }
    }
  rescue => e
    {error: e.message}
  end

  private

  def find_user(name:, id:)
    return User.find_by(id: id) if id.present?

    return nil if name.blank?

    User.find_by(name: name) ||
      User.find_by(slug: name) ||
      User.find_by(slug: name.parameterize)
  end

  def talk_to_hash(talk)
    {
      id: talk.id,
      title: talk.title,
      slug: talk.slug,
      date: talk.date&.to_s,
      event_name: talk.event&.name,
      video_provider: talk.video_provider,
      video_id: talk.video_id,
      slides_url: talk.slides_url.presence
    }.compact
  end
end
