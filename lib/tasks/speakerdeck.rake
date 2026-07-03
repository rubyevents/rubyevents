namespace :speakerdeck do
  require "gum"

  desc "Check for speakers with slides URLs but missing speakerdeck handle"
  task check: :environment do
    exit 1 unless validate_speakerdeck_handles
  end

  def validate_speakerdeck_handles
    scanner = Speakerdeck::SlidesScanner.new.scan
    speakers_file = Static::SpeakersFile.new
    candidates = scanner.candidates
    multi = scanner.multi_handle_speakers
    passed = true

    if multi.any?
      puts Gum.style("Speakers with multiple SpeakerDeck handles (#{multi.size}):", foreground: "1")
      puts

      multi.each do |name, handles|
        puts Gum.style("  ❌ #{name}: #{handles.to_a.join(", ")}", foreground: "1")
      end

      puts
      puts Gum.style("If generic/shared: add to Speakerdeck::SlidesScanner::IGNORED_HANDLES", foreground: "3")
      puts Gum.style("If legitimate: manually set 'speakerdeck' in speakers.yml", foreground: "3")
      puts

      passed = false
    end

    missing = candidates.select do |name, _handles|
      speaker = speakers_file.find_by(name: name)
      speaker && speaker.value_at("speakerdeck").nil?
    end

    if missing.any?
      puts Gum.style("Speakers with slides URLs but no speakerdeck handle (#{missing.size}):", foreground: "1")
      puts

      missing.each do |name, handles|
        puts Gum.style("  ❌ #{name} → #{handles.first}", foreground: "1")
      end

      puts
      puts Gum.style("Run: rails speakerdeck:sync", foreground: "3")

      passed = false
    end

    if passed
      puts Gum.style("✓ All SpeakerDeck handles are valid", foreground: "2")
    end

    passed
  end

  desc "Sync speakerdeck handles from slides URLs in videos to speakers.yml"
  task sync: :environment do
    puts Gum.style("Setting SpeakerDeck usernames from slides URLs", border: "rounded", padding: "0 2", border_foreground: "5")
    puts

    scanner = Speakerdeck::SlidesScanner.new.scan
    speakers_file = Static::SpeakersFile.new
    multi = scanner.multi_handle_speakers

    if multi.any?
      puts Gum.style("Speakers with multiple SpeakerDeck handles:", foreground: "3")

      multi.each do |name, handles|
        puts "  ⚠ #{name}: #{handles.to_a.join(", ")}"
      end

      puts
      puts Gum.style("If any of these are generic/shared handles, add them to Speakerdeck::SlidesScanner::IGNORED_HANDLES", foreground: "3")
      puts
    end

    candidates = scanner.candidates
    updated = 0

    puts "Found #{candidates.size} speakers with a unique SpeakerDeck handle from slides"
    puts

    candidates.each do |name, handles|
      speaker = speakers_file.find_by(name: name)
      next unless speaker

      handle = handles.first
      next if speaker.value_at("speakerdeck") == handle

      speaker["speakerdeck"] = handle

      puts Gum.style("✓ #{name} → #{handle}", foreground: "2")
      updated += 1
    end

    if updated > 0
      speakers_file.save!
      puts
      puts Gum.style("Updated #{updated} speakers in speakers.yml!", border: "rounded", padding: "0 2", foreground: "2", border_foreground: "2")
    else
      puts
      puts Gum.style("No speakers updated", border: "rounded", padding: "0 2", foreground: "3", border_foreground: "3")
    end
  end
end
