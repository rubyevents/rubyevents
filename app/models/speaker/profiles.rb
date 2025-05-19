# -*- SkipSchemaAnnotations
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

    speaker.build_twitter(links["twitter"]) if links["twitter"].present?
    speaker.build_mastodon(links["mastodon"]) if links["mastodon"].present?
    speaker.build_bsky(links["bluesky"]) if links["bluesky"].present?
    speaker.build_linkedin(links["linkedin"]) if links["linkedin"].present?
    speaker.build_website(profile.blog) if profile.blog.present?

    speaker.update!(
      bio: speaker.bio.presence || profile.bio || "",
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
