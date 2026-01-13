namespace :speakerdeck do
  require "gum"

  def render_progress_bar(current, total, width: 40)
    return if total.zero?

    percentage = (current.to_f / total * 100).round(1)
    filled = (current.to_f / total * width).round
    empty = width - filled

    bar = "█" * filled + "░" * empty
    "\r\e[K#{bar} #{percentage}% (#{current}/#{total})"
  end

  desc "Set speakerdeck name from slides_url"
  task set_usernames_from_slides_url: :environment do
    puts Gum.style("Setting SpeakerDeck usernames from slides URLs", border: "rounded", padding: "0 2", border_foreground: "5")
    puts

    users = User.distinct.where(speakerdeck: "").where.associated(:talks)
    total_count = users.count
    updated = 0
    processed = 0

    puts "Found #{total_count} speakers with no SpeakerDeck name"
    puts

    users.find_in_batches do |batch|
      batch.each do |user|
        speakerdeck_name = user.speakerdeck_user_from_slides_url

        if speakerdeck_name
          user.update!(speakerdeck: speakerdeck_name)
          print "\r\e[K"
          puts Gum.style("✓ #{user.name} → #{speakerdeck_name}", foreground: "2")
          updated += 1
        end

        processed += 1
        print render_progress_bar(processed, total_count) unless ENV["GITHUB_ACTIONS"]
      end
    end

    puts "\n"

    if updated > 0
      puts Gum.style("Updated #{updated} speakers!", border: "rounded", padding: "0 2", foreground: "2", border_foreground: "2")
    else
      puts Gum.style("No speakers updated", border: "rounded", padding: "0 2", foreground: "3", border_foreground: "3")
    end
  end
end
