desc "Fetch thumbnails for meta talks for all cues"
task extract_thumbnails: :environment do |t, args|
  Talk.where(meta_talk: true).each do |meta_video|
    meta_video.thumbnails.extract!
  end
end

namespace :thumbnails do
  desc <<~DESC.strip
    Generate PNG thumbnails for talks. Options (env vars):
      EVENT=<event-slug>   only talks for this event
      SLUG=<talk-slug>     only this talk
      VARIANT=both|classic|spotlight   (default: both)
      DISK=1               write to tmp/thumbnails/generated/ instead of ActiveStorage
      FORCE=1              regenerate even if it already exists
      ASYNC=1              enqueue jobs instead of generating inline (ActiveStorage only)
    Example: bin/rails thumbnails:generate EVENT=rubycon-2026 VARIANT=both DISK=1
  DESC
  task generate: :environment do
    force = ENV["FORCE"].present?
    async = ENV["ASYNC"].present?
    disk = ENV["DISK"].present?

    variants = case ENV["VARIANT"]
    when "classic", "spotlight" then [ENV["VARIANT"]]
    when nil, "", "both" then Talk::ThumbnailGenerator::VARIANTS
    else abort("Unknown VARIANT=#{ENV["VARIANT"].inspect} (use both|classic|spotlight)")
    end

    scope = Talk.includes(:event, :speakers)
    scope = if ENV["EVENT"].present?
      scope.joins(:event).where(events: {slug: ENV["EVENT"]})
    elsif ENV["SLUG"].present?
      scope.where(slug: ENV["SLUG"]).where.associated(:event)
    else
      scope.where.associated(:event)
    end

    talks = scope.to_a
    total = talks.size * variants.size
    puts "Generating #{variants.join("+")} thumbnail(s) for #{talks.size} talk(s) = #{total}#{" to disk" if disk}#{" (async)" if async}#{" (force)" if force}..."

    done = 0
    generated = 0
    skipped = 0

    talks.each do |talk|
      variants.each do |variant|
        done += 1
        gen = Talk::ThumbnailGenerator.new(talk, variant: variant)

        already = disk ? gen.disk_path.exist? : gen.exists?
        if already && !force
          skipped += 1
          next
        end

        if async && !disk
          GenerateTalkThumbnailJob.perform_later(talk, variant)
          generated += 1
          next
        end

        result = disk ? gen.write_to_disk : gen.save_to_storage
        if result
          generated += 1
          puts "[#{done}/#{total}] ✓ #{variant} · #{talk.slug}"
        else
          puts "[#{done}/#{total}] ✗ #{variant} · #{talk.slug}"
        end
      end
    end

    puts "Done. #{generated} generated/enqueued, #{skipped} skipped (already present)."
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
