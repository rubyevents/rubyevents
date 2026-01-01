namespace :transcripts do
  desc "Extract YouTube transcripts using yt-dlp for talks without transcripts"
  task :extract, [:event_slug] => :environment do |_t, args|
    event_slug = args[:event_slug]

    talks = Talk.where(date: Date.new(2025, 1, 1)..Date.new(2026, 1, 2)).youtube.left_joins(:talk_transcript).where(talk_transcripts: {id: nil})

    if event_slug.present?
      talks = talks.joins(:event).where(events: {slug: event_slug})
    end

    total_count = talks.count
    puts "Found #{total_count} YouTube talks without transcripts"

    # Configurable delay between requests to avoid rate limiting
    delay_seconds = ENV.fetch("TRANSCRIPT_DELAY", 3).to_i

    talks.find_each.with_index do |talk, index|
      puts "\n[#{index + 1}/#{total_count}]"
      TranscriptExtractor.new(talk, delay: delay_seconds).extract!
    end
  end

  desc "Import transcripts from YAML files into the database"
  task import: :environment do
    Static::Transcript.import_all!
    puts "Imported #{Static::Transcript.count} transcripts"
  end
end

class TranscriptExtractor
  YTDLP_BIN = ENV.fetch("YTDLP_BIN", "yt-dlp")
  MAX_RETRIES = 5
  INITIAL_BACKOFF = 30 # seconds

  attr_reader :talk, :delay

  def initialize(talk, delay: 3)
    @talk = talk
    @delay = delay
  end

  def extract!
    return unless talk.youtube?
    return unless talk.event&.series

    puts "Extracting transcript for: #{talk.title} (#{talk.video_id})"

    vtt_content = download_transcript_with_retry
    return if vtt_content.blank?

    transcript = Transcript.create_from_vtt(vtt_content)
    return unless transcript.present?

    save_to_yaml(transcript)
    puts "  -> Saved transcript with #{transcript.cues.size} cues"

    # Add delay between successful requests to avoid rate limiting
    puts "  -> Waiting #{delay}s before next request..."
    sleep(delay)
  rescue => e
    puts "  -> Error extracting transcript: #{e.message}"
  end

  private

  def download_transcript_with_retry
    retries = 0

    loop do
      result = download_transcript

      # Check if we got rate limited
      if result[:rate_limited]
        retries += 1

        if retries > MAX_RETRIES
          puts "  -> Max retries (#{MAX_RETRIES}) exceeded. Skipping..."
          return nil
        end

        backoff = INITIAL_BACKOFF * (2**(retries - 1)) # Exponential backoff: 30s, 60s, 120s, 240s, 480s
        puts "  -> Rate limited! Retry #{retries}/#{MAX_RETRIES} in #{backoff}s..."
        sleep(backoff)
      else
        return result[:content]
      end
    end
  end

  def download_transcript
    tmp_dir = Rails.root.join("tmp", "transcripts")
    FileUtils.mkdir_p(tmp_dir)

    output_template = tmp_dir.join(talk.video_id)

    # Download auto-generated subtitles with yt-dlp retry options
    command = [
      YTDLP_BIN,
      "--write-auto-sub",
      "--sub-lang", "en",
      "--sub-format", "vtt",
      "--skip-download",
      "--no-warnings",
      "--output", "\"#{output_template}\"",
      "\"#{talk.provider_url}\""
    ].join(" ")

    puts "  -> Running: #{command}"
    output = `#{command} 2>&1`

    # Check for rate limiting in the output
    if output.include?("429") || output.include?("Too Many Requests")
      return {rate_limited: true, content: nil}
    end

    # Find the downloaded VTT file
    vtt_file = Dir.glob("#{output_template}*.vtt").first
    return {rate_limited: false, content: nil} unless vtt_file && File.exist?(vtt_file)

    content = File.read(vtt_file)
    File.delete(vtt_file) # Clean up
    {rate_limited: false, content: content}
  end

  def save_to_yaml(transcript)
    series_slug = talk.event.series.slug
    event_slug = talk.event.slug
    transcripts_file = Rails.root.join("data", series_slug, event_slug, "transcripts.yml")

    # Load existing transcripts or start fresh
    existing_transcripts = if File.exist?(transcripts_file)
      YAML.load_file(transcripts_file) || []
    else
      []
    end

    # Remove any existing entry for this video_id
    existing_transcripts.reject! { |t| t["video_id"] == talk.video_id }

    # Add the new transcript
    transcript_data = {
      "video_id" => talk.video_id,
      "cues" => transcript.to_h.map { |cue|
        {
          "start_time" => cue[:start_time],
          "end_time" => cue[:end_time],
          "text" => cue[:text]
        }
      }
    }

    existing_transcripts << transcript_data

    # Write to file
    File.write(transcripts_file, existing_transcripts.to_yaml)
  end
end
