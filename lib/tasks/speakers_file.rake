namespace :speakers_file do
  desc "Show speakers.yml stats"
  task stats: :environment do
    speakers = Static::SpeakersFile.new

    puts "Speakers: #{speakers.count}"
    puts "Known names (incl. aliases): #{speakers.known_names.size}"
    puts "Referenced in videos/involvements: #{speakers.all_referenced_names.size}"
    puts "Missing from speakers.yml: #{speakers.missing_speakers.length}"
    puts "Orphaned in speakers.yml: #{speakers.orphaned_speakers.length}"
    puts "Duplicate slugs: #{speakers.duplicate_slugs.size}"
    puts "Duplicate githubs: #{speakers.duplicate_githubs.size}"
  end

  desc "List speakers referenced in videos but missing from speakers.yml"
  task missing: :environment do
    speakers = Static::SpeakersFile.new
    missing = speakers.missing_speakers

    if missing.empty?
      puts "All speakers in videos exist in speakers.yml"
    else
      puts "Missing speakers (#{missing.length}):"
      puts
      missing.each { |name| puts "  - #{name}" }
    end
  end

  desc "Add missing speakers to speakers.yml"
  task add_missing: :environment do
    speakers = Static::SpeakersFile.new
    added = speakers.add_missing_speakers

    if added.empty?
      puts "No missing speakers to add"
    else
      puts "Added #{added.length} speakers:"
      puts
      added.each { |name| puts "  + #{name}" }

      speakers.save!
      puts
      puts "Saved speakers.yml (#{speakers.count} total)"
    end
  end

  desc "List orphaned speakers in speakers.yml (not referenced in any video or involvement)"
  task orphaned: :environment do
    speakers = Static::SpeakersFile.new
    orphaned = speakers.orphaned_speakers

    if orphaned.empty?
      puts "No orphaned speakers found"
    else
      puts "Orphaned speakers (#{orphaned.length}):"
      puts
      orphaned.sort.each { |name| puts "  - #{name}" }
    end
  end

  desc "Remove orphaned speakers from speakers.yml"
  task remove_orphaned: :environment do
    speakers = Static::SpeakersFile.new
    removed = speakers.remove_orphaned_speakers!

    if removed.empty?
      puts "No orphaned speakers to remove"
    else
      puts "Removed #{removed.length} speakers:"
      puts
      removed.sort.each { |name| puts "  - #{name}" }

      speakers.save!
      puts
      puts "Saved speakers.yml (#{speakers.count} total)"
    end
  end

  desc "Sync speakers.yml: add missing and remove orphaned speakers"
  task sync: :environment do
    speakers = Static::SpeakersFile.new

    puts "Before: #{speakers.count} speakers"
    puts

    added = speakers.add_missing_speakers
    removed = speakers.remove_orphaned_speakers!

    if added.any?
      puts "Added #{added.length} missing speakers:"
      added.each { |name| puts "  + #{name}" }
      puts
    end

    if removed.any?
      puts "Removed #{removed.length} orphaned speakers:"
      removed.sort.each { |name| puts "  - #{name}" }
      puts
    end

    if added.empty? && removed.empty?
      puts "speakers.yml is in sync"
    else
      speakers.save!
      puts "After: #{speakers.count} speakers"
      puts "Saved speakers.yml"
    end
  end

  desc "Check if speakers.yml is in sync (exits 1 if not)"
  task check: :environment do
    speakers = Static::SpeakersFile.new
    missing = speakers.missing_speakers
    orphaned = speakers.orphaned_speakers
    in_sync = missing.empty? && orphaned.empty?

    if in_sync
      puts "✓ speakers.yml is in sync"
    else
      if missing.any?
        puts "✗ #{missing.length} speakers referenced in videos but missing from speakers.yml:"
        missing.first(10).each { |name| puts "    - #{name}" }
        puts "    ... and #{missing.length - 10} more" if missing.length > 10
        puts
      end

      if orphaned.any?
        puts "✗ #{orphaned.length} orphaned speakers in speakers.yml (not referenced anywhere):"
        orphaned.sort.first(10).each { |name| puts "    - #{name}" }
        puts "    ... and #{orphaned.length - 10} more" if orphaned.length > 10
        puts
      end

      puts "Run `rails speakers_file:sync` to fix and review the output."
      exit 1
    end
  end
end
