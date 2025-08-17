namespace :speakers do
  desc "Migrate speaker data to users table"
  task migrate_to_users: :environment do
    puts "Starting migration of speakers to users..."

    ActiveRecord::Base.transaction do
      # Step 1: Migrate speakers with matching users
      speakers_with_users = Speaker.joins(:user).includes(:user, :speaker_talks)
      puts "Migrating #{speakers_with_users.count} speakers with existing users..."

      speakers_with_users.find_each do |speaker|
        user = speaker.user
        puts "  Migrating speaker: #{speaker.name} -> user: #{user.name}"

        # Skip if user already has speaker data migrated
        next if user.slug.present? && user.slug == speaker.slug

        # Copy speaker attributes to user
        user.update!(
          bio: speaker.bio,
          website: speaker.website,
          slug: speaker.slug,
          twitter: speaker.twitter,
          bsky: speaker.bsky,
          mastodon: speaker.mastodon,
          linkedin: speaker.linkedin,
          speakerdeck: speaker.speakerdeck,
          pronouns: speaker.pronouns,
          pronouns_type: speaker.pronouns_type,
          talks_count: speaker.talks_count,
          canonical_id: nil, # Will be handled later
          bsky_metadata: speaker.bsky_metadata,
          github_metadata: speaker.github_metadata
        )

        # Create UserTalk records for each SpeakerTalk
        speaker.speaker_talks.each do |speaker_talk|
          UserTalk.find_or_create_by!(
            user: user,
            talk: speaker_talk.talk
          ) do |user_talk|
            user_talk.discarded_at = speaker_talk.discarded_at
            user_talk.created_at = speaker_talk.created_at
            user_talk.updated_at = speaker_talk.updated_at
          end
        end
      end

      # Step 2: Create user accounts for orphaned speakers
      orphaned_speakers = Speaker.left_joins(:user).where(users: {id: nil}).includes(:speaker_talks)
      puts "Creating users for #{orphaned_speakers.count} orphaned speakers..."

      orphaned_speakers.find_each do |speaker|
        puts "  Creating user for orphaned speaker: #{speaker.name}"

        # Generate a secure random password
        secure_password = SecureRandom.hex(20)

        # Skip if user already exists for this speaker
        next if User.find_by(slug: speaker.slug).present?

        # Create user from speaker data
        user = User.create!(
          email: "#{speaker.slug}@rubyvideo.org", # Temporary email
          password: secure_password,
          password_confirmation: secure_password,
          name: speaker.name,
          github_handle: speaker.github.present? ? speaker.github : nil,
          bio: speaker.bio,
          website: speaker.website,
          slug: speaker.slug,
          twitter: speaker.twitter,
          bsky: speaker.bsky,
          mastodon: speaker.mastodon,
          linkedin: speaker.linkedin,
          speakerdeck: speaker.speakerdeck,
          pronouns: speaker.pronouns,
          pronouns_type: speaker.pronouns_type,
          talks_count: speaker.talks_count,
          canonical_id: nil, # Will be handled later
          bsky_metadata: speaker.bsky_metadata,
          github_metadata: speaker.github_metadata,
          verified: false,
          admin: false
        )

        # Create UserTalk records for each SpeakerTalk
        speaker.speaker_talks.each do |speaker_talk|
          UserTalk.find_or_create_by!(
            user: user,
            talk: speaker_talk.talk
          ) do |user_talk|
            user_talk.discarded_at = speaker_talk.discarded_at
            user_talk.created_at = speaker_talk.created_at
            user_talk.updated_at = speaker_talk.updated_at
          end
        end

        # Store mapping for canonical relationship handling
        user.update_column(:canonical_id, speaker.canonical_id) if speaker.canonical_id
      end

      # Step 3: Update canonical relationships to reference users
      puts "Updating canonical relationships..."
      users_with_canonical = User.where.not(canonical_id: nil)

      users_with_canonical.find_each do |user|
        # Find the speaker that this user was canonical to
        canonical_speaker = Speaker.find_by(id: user.canonical_id)
        next unless canonical_speaker

        # Find the user that corresponds to the canonical speaker
        canonical_user = if canonical_speaker.user.present?
          canonical_speaker.user
        else
          # Find user created from this speaker by matching slug
          User.find_by(slug: canonical_speaker.slug)
        end

        if canonical_user
          user.update_column(:canonical_id, canonical_user.id)
          puts "  Updated canonical: #{user.name} -> #{canonical_user.name}"
        else
          puts "  Warning: Could not find canonical user for #{user.name}"
          user.update_column(:canonical_id, nil)
        end
      end

      puts "Migration completed successfully!"
      puts "Summary:"
      puts "  Total users: #{User.count}"
      puts "  Users with talks: #{User.where.not(talks_count: 0).count}"
      puts "  Total user_talks: #{UserTalk.count}"
      puts "  Users with canonical relationships: #{User.where.not(canonical_id: nil).count}"
    end
  rescue => e
    puts "Migration failed: #{e.message}"
    puts e.backtrace
    raise
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
