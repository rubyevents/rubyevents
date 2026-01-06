class User::SuspicionDetector < ActiveRecord::AssociatedObject
  SIGNAL_THRESHOLD = 3
  GITHUB_ACCOUNT_AGE_THRESHOLD = 6.months

  extension do
    scope :verified, -> {
      joins(:connected_accounts).where(connected_accounts: {provider: "github"}).distinct
    }

    scope :with_github_account_older_than, ->(duration) {
      with_github.where("json_extract(github_metadata, '$.profile.created_at') < ?", duration.ago.iso8601)
    }

    scope :with_github_account_newer_than, ->(duration) {
      with_github.where("json_extract(github_metadata, '$.profile.created_at') >= ?", duration.ago.iso8601)
    }

    scope :suspicion_cleared, -> { where.not(suspicion_cleared_at: nil) }
    scope :suspicion_not_cleared, -> { where(suspicion_cleared_at: nil) }
    scope :suspicion_marked, -> { where.not(suspicion_marked_at: nil) }
    scope :suspicion_not_marked, -> { where(suspicion_marked_at: nil) }

    scope :suspicious, -> { suspicion_marked.suspicion_not_cleared }
    scope :not_suspicious, -> { suspicion_not_marked.or(suspicion_cleared) }

    def suspicious?
      suspicion_marked_at.present? && suspicion_cleared_at.blank?
    end

    def suspicion_cleared?
      suspicion_cleared_at.present?
    end

    def mark_suspicious!
      return false unless suspicion_detector.calculate_suspicious?

      update_column(:suspicion_marked_at, Time.current)
      true
    end

    def clear_suspicion!
      update!(suspicion_cleared_at: Time.current, suspicion_marked_at: nil)
    end

    def unclear_suspicion!
      update!(suspicion_cleared_at: nil)
    end

    def github_account_newer_than?(duration)
      return false if github_metadata.blank?

      created_at = github_metadata.dig("profile", "created_at")
      return false if created_at.blank?

      Time.parse(created_at) > duration.ago
    end
  end

  def calculate_suspicious?
    return false unless user.verified?
    return false if user.suspicion_cleared?
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
