desc "Fetch thumbnails for meta talks for all cues"
task extract_thumbnails: :environment do |t, args|
  Talk.where(meta_talk: true).each do |meta_video|
    meta_video.thumbnails.extract!
  end
end

desc "Move thumbnails to thumbnails/<event-slug>/(<parent-talk-id>/)<video_id>.webp"
task reorg_thumbnails: :environment do
  lookup = Static::Validators::RedundantThumbnails.talk_lookup
  directory = Rails.root.join("app/assets/images/thumbnails")
  moved = 0
  unknown = []

  Dir.glob(directory.join("**/*.webp")).each do |path|
    basename = File.basename(path, ".webp")
    entry = lookup[basename]
    next unknown << path.sub("#{Rails.root}/", "") unless entry

    target = directory.join(*[entry[:event_slug], entry[:parent_id], "#{basename}.webp"].compact)
    next if target.to_s == path

    target.dirname.mkpath
    FileUtils.mv(path, target)
    moved += 1

    puts "#{path.sub("#{Rails.root}/", "")} -> #{target.to_s.sub("#{Rails.root}/", "")}"
  end

  Dir.glob(directory.join("**/")).sort_by(&:length).reverse_each { |dir| Dir.rmdir(dir) if Dir.empty?(dir) }

  puts
  puts "Moved #{moved} thumbnail(s)"

  if unknown.any?
    puts
    puts "Skipped #{unknown.size} thumbnail(s) without a matching talk:"
    unknown.each { |path| puts "  #{path}" }
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
