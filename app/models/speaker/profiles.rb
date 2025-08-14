class Speaker::Profiles < ActiveRecord::AssociatedObject
  performs(retries: 3) { limits_concurrency key: -> { it.id } }

  def enhance_all_later
    enhance_with_github_later
    enhance_with_bsky_later
  end

  performs def enhance_with_github(force: false)
    return unless speaker.github?
    return if speaker.verified? && !force

    profile = github_client.profile(speaker.github)
    socials = github_client.social_accounts(speaker.github)
    links = socials.pluck(:provider, :url).to_h

    speaker.update!(
      twitter: speaker.twitter.presence || links["twitter"] || "",
      mastodon: speaker.mastodon.presence || links["mastodon"] || "",
      bsky: speaker.bsky.presence || links["bluesky"] || "",
      linkedin: speaker.linkedin.presence || links["linkedin"] || "",
      bio: speaker.bio.presence || profile.bio || "",
      website: speaker.website.presence || profile.blog || "",
      github_metadata: {
        profile: JSON.parse(profile.body),
        socials: JSON.parse(socials.body)
      }
    )

    speaker.broadcast_header
  end

  performs def enhance_with_bsky(force: false)
    return unless speaker.bsky?
    return if speaker.verified? && !force

    speaker.update!(bsky_metadata: BlueSky.profile_metadata(speaker.bsky))
  end

  private

  def github_client
    @github_client ||= GitHub::UserClient.new
  end
end
