namespace :speakers do
  desc "Migrate speaker data to users table"
  task migrate_to_users: :environment do
    puts "Starting migration of canonical speakers to users..."
    Speaker.canonical.each do |speaker|
      user = speaker.user || (speaker.slug.present? ? User.find_by(slug: speaker.slug) : nil)
      attributes = speaker.attributes.except("id", "created_at", "updated_at", "canonical_id", "github")
      attributes["github_handle"] = speaker.github
      if user.present?

        puts "Updating user #{user.name} with speaker data"
        user.update!(**attributes)

      else

        puts "Creating user #{speaker.name} with speaker data"
        user = User.create!(**attributes)
        speaker.update!(user: user)

      end

      # Create UserTalk records for each SpeakerTalk
      puts "Creating UserTalk records for #{speaker.name}"
      speaker.reload.speaker_talks.each do |speaker_talk|
        UserTalk.find_or_create_by(user: user, talk: speaker_talk.talk) do |user_talk|
          user_talk.discarded_at = speaker_talk.discarded_at
          user_talk.created_at = speaker_talk.created_at
          user_talk.updated_at = speaker_talk.updated_at
        end
      end
    end

    puts "Processing non-canonical speakers"
    Speaker.not_canonical.each do |speaker|
      puts "Processing speaker #{speaker.name}"
      @user = speaker.user || User.find_by(slug: speaker.slug)
      attributes = speaker.attributes.except("id", "created_at", "updated_at", "canonical_id", "github")
      attributes["github_handle"] = speaker.github
      @canonical_user = speaker.canonical.user

      next if @user == @canonical_user

      if @user
        @user.update!(**attributes)
      else
        @user = User.create!(**attributes)
        speaker.update!(user: @user)
      end

      @user.update!(canonical: @canonical_user)
    end

    puts "Migration completed successfully!"
    puts "Summary:"
    puts "  Total users: #{User.count}"
    puts "  Total users with github_handle: #{User.with_github.count}"
    puts "  Total users canonical: #{User.canonical.count}"
    puts "  Users with talks: #{User.where.not(talks_count: 0).count}"
    puts "  Total user_talks: #{UserTalk.count}"
    puts "  Users with canonical relationships: #{User.where.not(canonical_id: nil).count}"
  end

  desc "Verify the migration was successful"
  task verify_migration: :environment do
    puts "Verifying migration..."

    # Check that all speakers have corresponding users
    total_speakers = Speaker.count
    speakers_with_users = Speaker.joins(:user).count

    puts "Speakers: #{total_speakers}"
    puts "Speakers with users: #{speakers_with_users}"
    puts "Users created from speakers: #{User.where("email LIKE ?", "%@rubyvideo.org").count}"

    # Check talk relationships
    total_speaker_talks = SpeakerTalk.count
    total_user_talks = UserTalk.count

    puts "SpeakerTalks: #{total_speaker_talks}"
    puts "UserTalks: #{total_user_talks}"

    # Check for any missing relationships
    talks_missing_users = Talk.left_joins(:user_talks).where(user_talks: {id: nil}).count
    puts "Talks without user relationships: #{talks_missing_users}"

    if talks_missing_users == 0 && total_user_talks >= total_speaker_talks
      puts "✅ Migration verification passed!"
    else
      puts "❌ Migration verification failed!"
    end
  end
end
