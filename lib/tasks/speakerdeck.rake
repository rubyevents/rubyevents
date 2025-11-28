namespace :speakerdeck do
  desc "Set speakerdeck name from slides_url"
  task set_usernames_from_slides_url: :environment do
    users = User.distinct.where(speakerdeck: "").where.associated(:talks)
    updated = 0
    processed = 0

    puts "Found #{users.count} speakers with no speakerdeck name"

    users.find_in_batches do |batch|
      batch.each do |user|
        speakerdeck_name = user.speakerdeck_user_from_slides_url

        if speakerdeck_name
          user.update!(speakerdeck: speakerdeck_name)
          puts %(Updating "#{user.name}" (id: #{user.id}) with Speakerdeck name "#{user.speakerdeck_user_from_slides_url}")
          updated += 1
        end
      end

      processed += batch.count
      puts "Processed #{processed}/#{users.count} speakers..."
    end

    puts "Updated #{updated} speakers"
  end
end
