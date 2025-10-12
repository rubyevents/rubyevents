class Recurring::FetchContributorsJob < ApplicationJob
  queue_as :low

  def perform
    return if ENV["SEED_SMOKE_TEST"]

    Rails.logger.info "Fetching contributors from GitHub..."
    contributors_data = GitHub::ContributorsClient.new.fetch_all

    Rails.logger.info "Fetched #{contributors_data.count} contributors"

    Contributor.transaction do
      Contributor.destroy_all

      contributors_data.each do |contributor_data|
        user = User.find_by("LOWER(github_handle) = LOWER(?)", contributor_data[:login])

        Contributor.create!(
          login: contributor_data[:login],
          name: contributor_data[:name],
          avatar_url: contributor_data[:avatar_url],
          html_url: contributor_data[:html_url],
          user: user
        )

        Rails.logger.info "Updated #{contributor_data[:login]} with contributor data."
      end

      Rails.logger.info "Successfully synced #{contributors_data.count} contributors"
    end
  rescue => e
    Rails.logger.error "Failed to fetch contributors: #{e.message}"
    raise
  end
end
