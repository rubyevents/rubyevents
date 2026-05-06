namespace :speakerdeck do
  require "gum"

  desc "Set speakerdeck name in speakers.yml from slides_url in videos"
  task set_usernames_from_slides_url: :environment do
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
    end

    candidates = scanner.candidates
    updated = 0

    puts "Found #{candidates.size} speakers with a unique SpeakerDeck handle from slides"
    puts

    candidates.each do |name, handles|
      speaker = speakers_file.find_by(name: name)
      next unless speaker

      handle = handles.first
      next if speaker.key?("speakerdeck") && speaker["speakerdeck"].to_s == handle

      if speaker.key?("speakerdeck")
        speaker["speakerdeck"] = handle
      else
        speaker.insert(:speakerdeck, handle)
      end
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
