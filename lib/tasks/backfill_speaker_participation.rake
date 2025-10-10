namespace :backfill do
  desc "Backfill EventParticipation records for existing speakers"
  task speaker_participation: :environment do
    puts "Starting backfill of speaker participation records..."

    # Query all UserTalk records with discarded_at: nil
    user_talks = UserTalk.includes(:user, talk: :event).where(discarded_at: nil)
    total_count = user_talks.count
    processed_count = 0
    created_count = 0
    error_count = 0

    puts "Found #{total_count} user-talk relationships to process"

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
            puts "Failed to create participation for user #{user.id} at event #{event.id}: #{participation.errors.full_messages.join(", ")}"
            error_count += 1
          end
        rescue => e
          puts "Error processing user_talk #{user_talk.id}: #{e.message}"
          error_count += 1
        end

        processed_count += 1

        # Progress reporting every 100 records
        if processed_count % 100 == 0
          puts "Processed #{processed_count}/#{total_count} records (#{(processed_count.to_f / total_count * 100).round(1)}%)"
        end
      end
    end

    puts "\nBackfill completed!"
    puts "Total processed: #{processed_count}"
    puts "New participations created: #{created_count}"
    puts "Errors: #{error_count}"
  end
end
