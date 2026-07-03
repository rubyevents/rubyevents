desc "Fetch thumbnails for meta talks for all cues"
task extract_thumbnails: :environment do |t, args|
  Talk.where(meta_talk: true).each do |meta_video|
    meta_video.thumbnails.extract!
  end
end

desc "Verify all talks with start_cue have thumbnails"
task verify_thumbnails: :environment do |t, args|
  thumbnails_count = 0
  child_talks_with_missing_thumbnails = []

  Talk.where(meta_talk: true).flat_map(&:child_talks).each do |child_talk|
    if child_talk.static_metadata
      if child_talk.static_metadata.start_cue.present? && child_talk.static_metadata.start_cue != "TODO"
        if child_talk.thumbnails.path.exist?
          thumbnails_count += 1
        else
          puts "missing thumbnail for child_talk: #{child_talk.video_id} at: #{child_talk.thumbnails.path}"
          child_talks_with_missing_thumbnails << child_talk
        end
      end
    else
      puts "missing static_metadata for child_talk: #{child_talk.video_id}"
      child_talks_with_missing_thumbnails << child_talk
    end
  end

  if child_talks_with_missing_thumbnails.any?
    raise "missing #{child_talks_with_missing_thumbnails.count} thumbnails"
  else
    puts "All #{thumbnails_count} thumbnails present!"
  end
end
