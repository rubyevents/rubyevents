class Talk::Thumbnails < ActiveRecord::AssociatedObject
  def path
    directory / "#{talk.video_id}.webp"
  end

  def extractable?
    talk.meta_talk? && talk.static_metadata&.talks&.any? && !start_cues.include?("TODO")
  end

  def start_cues
    talk.static_metadata.talks.map { |talk| talk.start_cue || "TODO" }
  end

  def extracted?
    talk.child_talks.map { |child_talk| child_talk.thumbnails.path.exist? }.reduce(:&)
  end

  def extract!(force: false, download: false)
    if !extractable?
      puts "Talk #{talk.video_id} is not extractable. Skipping..."

      return
    end

    if extracted? && !force
      puts "All thumbnails for child_talks of #{talk.video_id} are extracted already. Skipping..."

      return
    end

    if !talk.downloader.downloaded?
      if download
        puts "#{talk.video_id} is not downloaded. Downloading..."

        talk.downloader.download!
      else
        puts "#{talk.video_id} is not downloaded. Skipping..."

        return
      end
    end

    talk.child_talks.each do |child_talk|
      if child_talk.static_metadata&.start_cue == "TODO"
        puts "start_cue of #{child_talk.video_id} is TODO. Skipping..."
        next
      end

      if child_talk.static_metadata.blank?
        puts "static_metadata of #{child_talk.video_id} is missing. Skipping..."
        next
      end

      extract_thumbnail(child_talk.static_metadata.thumbnail_cue, talk.downloader.download_path, child_talk.thumbnails.path)
    end
  end

  def extract_thumbnail(timestamp, input_file, output_file)
    Command.run(%(ffmpeg -y -ss #{timestamp} -i "#{input_file}" -map 0:v:0 -frames:v 1 -q:v 50 -vf scale=1080:-1 "#{output_file}"))
  end

  private

  def directory
    Rails.root.join("app/assets/images/thumbnails").tap(&:mkpath)
  end
end
