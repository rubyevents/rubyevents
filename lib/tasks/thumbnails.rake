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
