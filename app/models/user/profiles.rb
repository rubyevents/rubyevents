class User::Profiles < ActiveRecord::AssociatedObject
  performs(retries: 3) { limits_concurrency key: -> { it.id } }

  def enhance_all_later
    enhance_with_github_later
    enhance_with_bsky_later
  end

  performs def enhance_with_github
    return unless user.github_handle?

    profile = github_client.profile(user.github_handle)
    socials = github_client.social_accounts(user.github_handle)
    links = socials.pluck(:provider, :url).to_h

    user.update!(
      twitter: user.twitter.presence || links["twitter"] || "",
      mastodon: user.mastodon.presence || links["mastodon"] || "",
      bsky: user.bsky.presence || links["bluesky"] || "",
      linkedin: user.linkedin.presence || links["linkedin"] || "",
      bio: user.bio.presence || profile.bio || "",
      website: user.website.presence || profile.blog || "",
      location: user.location.presence || profile.location || "",
      github_metadata: {
        profile: JSON.parse(profile.body),
        socials: JSON.parse(socials.body)
      }
    )

    user.broadcast_header
  end

  performs def enhance_with_bsky(force: false)
    return unless user.bsky?
    return if user.verified? && !force

    user.update!(bsky_metadata: BlueSky.profile_metadata(user.bsky))
  end

  private

  def github_client
    @github_client ||= GitHub::UserClient.new
  end
end
