namespace :backfill do
  require "gum"

  def render_progress_bar(current, total, width: 40)
    return if total.zero?

    percentage = (current.to_f / total * 100).round(1)
    filled = (current.to_f / total * width).round
    empty = width - filled

    bar = "█" * filled + "░" * empty
    "\r\e[K#{bar} #{percentage}% (#{current}/#{total})"
  end

  desc "Backfill EventParticipation records for existing speakers"
  task speaker_participation: :environment do
    puts Gum.style("Backfilling speaker participation records", border: "rounded", padding: "0 2", border_foreground: "5")
    puts

    # Query all UserTalk records with discarded_at: nil
    user_talks = UserTalk.includes(:user, talk: :event).where(discarded_at: nil)
    total_count = user_talks.count
    processed_count = 0
    created_count = 0
    error_count = 0

    puts "Found #{total_count} user-talk relationships to process"
    puts

    # Process in batches
    user_talks.find_in_batches(batch_size: 1000) do |batch|
      batch.each do |user_talk|
        begin
          user = user_talk.user
          talk = user_talk.talk
          event = talk.event

          next unless user && talk && event

          # Determine participation type based on talk kind
          participation_type = case talk.kind
          when "keynote"
            "keynote_speaker"
          else
            "speaker"
          end

          # Create EventParticipation record if it doesn't exist
          participation = EventParticipation.find_or_create_by(user: user, event: event, attended_as: participation_type)

          if participation.persisted?
            created_count += 1 if participation.previously_new_record?
          else
            print "\r\e[K"
            puts Gum.style("❌ Failed: user #{user.id} at event #{event.id}: #{participation.errors.full_messages.join(", ")}", foreground: "1")
            error_count += 1
          end
        rescue => e
          print "\r\e[K"
          puts Gum.style("❌ Error processing user_talk #{user_talk.id}: #{e.message}", foreground: "1")
          error_count += 1
        end

        processed_count += 1
        print render_progress_bar(processed_count, total_count) unless ENV["GITHUB_ACTIONS"] == "true"
      end
    end

    puts "\n"

    if error_count > 0
      puts Gum.style("Backfill completed with errors", border: "rounded", padding: "0 2", foreground: "3", border_foreground: "3")
    else
      puts Gum.style("Backfill completed!", border: "rounded", padding: "0 2", foreground: "2", border_foreground: "2")
    end

    puts
    puts "Total processed: #{processed_count}"
    puts Gum.style("✓ New participations created: #{created_count}", foreground: "2")
    puts Gum.style("#{(error_count > 0) ? "❌" : "✓"} Errors: #{error_count}", foreground: (error_count > 0) ? "1" : "2")
  end
end
