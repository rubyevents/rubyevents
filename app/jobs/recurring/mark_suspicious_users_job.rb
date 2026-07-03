class Recurring::MarkSuspiciousUsersJob < ApplicationJob
  queue_as :default

  def perform
    User.verified.not_suspicious.suspicion_not_cleared.find_each do |user|
      refresh_github_metadata(user)

      if user.mark_suspicious!
        Rails.logger.info("[MarkSuspiciousUsersJob] Marked user ##{user.id} (#{user.name}) as suspicious")
      end
    end
  end

  private

  def refresh_github_metadata(user)
    return if user.github_metadata.present?

    user.profiles.enhance_with_github
    user.reload
  rescue => e
    Rails.logger.warn("[MarkSuspiciousUsersJob] Failed to fetch GitHub metadata for user ##{user.id}: #{e.message}")
  end
end
