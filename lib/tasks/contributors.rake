namespace :contributors do
  desc "Fetch GitHub contributors and save to database"
  task fetch: :environment do
    Recurring::FetchContributorsJob.perform_now
  end
end
