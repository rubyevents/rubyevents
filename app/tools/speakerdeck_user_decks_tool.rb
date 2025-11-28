# frozen_string_literal: true

class SpeakerdeckUserDecksTool < RubyLLM::Tool
  description "Fetch all slide decks from a speaker's SpeakerDeck profile. Lookup by user name or slug."
  param :name, desc: "User name or slug to lookup in the database (e.g., 'Aaron Patterson' or 'tenderlove')"

  def execute(name:)
    user = User.find_by(name: name) ||
      User.find_by(slug: name) ||
      User.find_by(slug: name.parameterize)

    return {error: "User '#{name}' not found in database"} if user.nil?

    unless user.speakerdeck_feed.has_feed?
      return {error: "User '#{user.name}' has no SpeakerDeck username configured"}
    end

    decks = user.speakerdeck_feed.decks

    {
      user_id: user.id,
      user_name: user.name,
      username: user.speakerdeck_feed.username,
      profile_url: "https://speakerdeck.com/#{user.speakerdeck_feed.username}",
      deck_count: decks.size,
      decks: decks.map { |deck| deck_to_hash(deck) }
    }
  rescue => e
    {error: e.message}
  end

  private

  def deck_to_hash(deck)
    {
      title: deck.title,
      url: deck.url,
      description: deck.description&.strip,
      published_at: deck.published_at&.to_s
    }
  end
end
