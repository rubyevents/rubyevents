class Talk::Thumbnails < ActiveRecord::AssociatedObject
  DEFAULT_BACKGROUND = "#081625"
  DEFAULT_COLOR = "#FFFFFF"
  RELEVANT_ATTRIBUTES = %w[title slug date language video_provider video_id].freeze

  extension do
    has_one_attached :generated_thumbnail

    after_update_commit -> { thumbnails.purge_generated }, if: -> { thumbnails.outdated? }
  end

  def path
    directory / "#{talk.video_id}.webp"
  end

  def generated_path
    enqueue_generation

    Router.talk_thumbnail_path(talk_slug: talk.slug, variant: "spotlight", v: cache_version)
  rescue => e
    Rails.logger.warn("Talk::Thumbnails#generated_path failed for #{talk.id}: #{e.message}")

    talk.poster_thumbnail
  end

  def enqueue_generation(variant: "spotlight")
    return if Talk::ThumbnailGenerator.new(talk, variant: variant).exists?

    lock_key = ["thumbnail-generation", talk.id, variant, cache_version]
    return unless Rails.cache.write(lock_key, true, expires_in: 1.minute, unless_exist: true)

    GenerateTalkThumbnailJob.perform_later(talk, variant)
  rescue => e
    Rails.logger.warn("Talk::Thumbnails#enqueue_generation failed for #{talk.id}: #{e.message}")

    nil
  end

  def cache_version
    speaker_signature = talk.speakers.map { |speaker| [speaker.name, speaker.github_handle] }.sort

    payload = [
      talk.title, talk.date, talk.slug,
      talk.event&.name, talk.event&.featured_background, talk.event&.featured_color,
      talk.event&.city, talk.event&.country_code, talk.event&.location,
      speaker_signature
    ].join("|")

    Digest::SHA1.hexdigest(payload).first(12)
  end

  def outdated?
    talk.saved_changes.keys.intersect?(RELEVANT_ATTRIBUTES)
  end

  def purge_generated
    talk.generated_thumbnail.purge_later if talk.generated_thumbnail.attached?
  end

  def background
    talk.event&.static_metadata&.featured_background.presence || DEFAULT_BACKGROUND
  end

  def background_color
    background.start_with?("data:") ? DEFAULT_BACKGROUND : background
  end

  def text_color
    talk.event&.static_metadata&.featured_color.presence || DEFAULT_COLOR
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
