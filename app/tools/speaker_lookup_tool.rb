# frozen_string_literal: true

class SpeakerLookupTool < RubyLLM::Tool
  description "Search for speakers in the database by name, slug, github, or twitter handle. Returns matching speakers with their info."
  param :query, desc: "Search query (matches against name, slug, github, twitter). Case-insensitive."

  def execute(query:)
    pattern = "%#{query}%"

    users = User.where(
      "name LIKE :q OR slug LIKE :q OR github_handle LIKE :q OR twitter LIKE :q",
      q: pattern
    ).limit(25)

    users.map { |user| user_to_hash(user) }
  rescue => e
    {error: e.message}
  end

  private

  def user_to_hash(user)
    {
      id: user.id,
      name: user.name,
      slug: user.slug,
      github: user.github_handle.presence,
      twitter: user.twitter.presence,
      speakerdeck: user.speakerdeck.presence,
      website: user.website.presence,
      bio: user.bio.presence&.truncate(200),
      talks_count: user.talks_count
    }.compact
  end
end
