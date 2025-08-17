namespace :users do
  desc "add missing slugs to users"
  task add_missing_slugs: :environment do
    User.where(slug: [nil, ""]).find_each do |user|
      puts "Adding slug to user #{user.github_handle}"
      user.update!(slug: user.github_handle)
    end
  end
end
