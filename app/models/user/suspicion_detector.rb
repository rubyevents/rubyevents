class User::SuspicionDetector < ActiveRecord::AssociatedObject
  SIGNAL_THRESHOLD = 3
  GITHUB_ACCOUNT_AGE_THRESHOLD = 6.months

  extension do
    scope :with_github_account_older_than, ->(duration) {
      with_github.where("json_extract(github_metadata, '$.profile.created_at') < ?", duration.ago.iso8601)
    }

    scope :with_github_account_newer_than, ->(duration) {
      with_github.where("json_extract(github_metadata, '$.profile.created_at') >= ?", duration.ago.iso8601)
    }

    scope :suspicious, -> {
      joins(:connected_accounts)
        .where(connected_accounts: {provider: "github"})
        .where(id: all.select(&:suspicious?).map(&:id))
    }

    def suspicious?
      suspicion_detector.suspicious?
    end

    def cleared?
      cleared_at.present?
    end

    def clear!
      update!(cleared_at: Time.current)
    end

    def unclear!
      update!(cleared_at: nil)
    end

    def github_account_newer_than?(duration)
      return false if github_metadata.blank?

      created_at = github_metadata.dig("profile", "created_at")
      return false if created_at.blank?

      Time.parse(created_at) > duration.ago
    end
  end

  def suspicious?
    return false unless user.verified?
    return false if user.cleared?
    return false if user.passports.any?

    signals.count(true) >= SIGNAL_THRESHOLD
  end

  def signals
    [
      github_account_new?,
      no_talks?,
      no_watched_talks?,
      bio_contains_url?,
      github_account_empty?
    ]
  end

  def signal_count
    signals.count(true)
  end

  def github_account_new?
    return false if user.github_metadata.blank?

    created_at = user.github_metadata.dig("profile", "created_at")
    return false if created_at.blank?

    Time.parse(created_at) > GITHUB_ACCOUNT_AGE_THRESHOLD.ago
  end

  def no_talks?
    user.talks_count.zero?
  end

  def no_watched_talks?
    user.watched_talks_count.zero?
  end

  def bio_contains_url?
    return false if user.bio.blank?

    user.bio.match?(URI::DEFAULT_PARSER.make_regexp(%w[http https]))
  end

  def github_account_empty?
    return false if user.github_metadata.blank?

    profile = user.github_metadata["profile"]
    return false if profile.blank?

    profile["public_repos"].to_i.zero? &&
      profile["followers"].to_i.zero? &&
      profile["following"].to_i.zero?
  end
end
