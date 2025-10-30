class Recurring::FetchContributorsJob < ApplicationJob
  include ActiveJob::Continuable

  BATCH_SIZE = 50
  queue_as :low

  def perform
    return if ENV["SEED_SMOKE_TEST"]

    step :fetch_contributors do
      Rails.logger.info "Fetching contributors from GitHub..."
      @contributors_data = GitHub::ContributorsClient.new.fetch_all
      Rails.logger.info "Fetched #{@contributors_data.count} contributors"
    end

    step :clear_existing_contributors do
      Contributor.destroy_all
    end

    step :sync_contributors do |step|
      # Reload data if resuming (it's not persisted across job executions)
      @contributors_data ||= GitHub::ContributorsClient.new.fetch_all

      # Find starting index based on cursor
      start_index = step.cursor || 0

      # Process in batches
      @contributors_data[start_index..].each_slice(BATCH_SIZE).with_index do |batch, batch_index|
        Contributor.transaction do
          batch.each_with_index do |contributor_data, index_in_batch|
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
        end
        step.set! batch_index * BATCH_SIZE + batch.size + start_index
      end

      Rails.logger.info "Successfully synced #{@contributors_data.count} contributors"
    end
  rescue => e
    Rails.logger.error "Failed to fetch contributors: #{e.message}"
    raise
  end
end
