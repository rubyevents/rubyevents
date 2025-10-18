namespace :users do
  desc "add missing slugs to users"
  task add_missing_slugs: :environment do
    User.where(slug: [nil, ""]).find_each do |user|
      puts "Adding slug to user #{user.github_handle}"
      user.update!(slug: user.github_handle)
    end
  end

  desc "Update user locations from GitHub metadata"
  task update_locations: :environment do
    users = User.where(location: [nil, ""]).where.not(github_metadata: {})
    updated_count = 0

    users.each do |user|
      location = user.github_metadata.dig("profile", "location")

      next if location.blank?

      user.update(location: location)

      updated_count += 1

      puts "Updated location for #{user.name}: #{location}"
    end

    puts "Updated #{updated_count} user locations"
  end
end
