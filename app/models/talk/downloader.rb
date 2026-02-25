class Talk::Downloader < ActiveRecord::AssociatedObject
  def bin
    ENV.fetch("YTDLP_BIN", "yt-dlp")
  end

  def download_path
    Rails.root / "tmp" / "videos" / talk.video_provider / "#{talk.video_id}.mp4"
  end

  def downloaded?
    download_path.exist?
  end

  def downloadable?
    talk.youtube? || talk.mp4?
  end

  def download!
    if !downloadable?
      puts "Talk #{talk.video_id} is not a YouTube or mp4 video"

      return
    end

    if downloaded?
      puts "#{talk.video_id} exists, skipping..."

      return
    end

    puts "#{talk.video_id} downloading..."

    Command.run(%(#{bin} --output "#{download_path}" --format "bv*[ext=mp4]+ba[ext=m4a]/b[ext=mp4]" "#{talk.provider_url}"))
  end
end
