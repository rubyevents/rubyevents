class Transcript
  include Enumerable

  attr_reader :cues

  def initialize(cues: [])
    @cues = cues
  end

  def add_cue(cue)
    @cues << cue
  end

  def to_h
    @cues.map { |cue| cue.to_h }
  end

  def to_json
    to_h.to_json
  end

  def to_text
    @cues.map { |cue| cue.text }.join("\n\n")
  end

  def to_vtt
    vtt_content = "WEBVTT\n\n"
    @cues.each_with_index do |cue, index|
      vtt_content += "#{index + 1}\n"
      vtt_content += "#{cue}\n\n"
    end
    vtt_content
  end

  def presence
    @cues.any? ? self : nil
  end

  def present?
    @cues.any?
  end

  def each(&)
    @cues.each(&)
  end

  class << self
    def create_from_vtt(vtt_content)
      transcript = Transcript.new
      return transcript if vtt_content.blank?

      # Remove WEBVTT header and any metadata lines
      lines = vtt_content.lines.map(&:strip)

      # Skip header lines (WEBVTT, Kind:, Language:, NOTE, etc.)
      content_started = false
      current_cue = nil
      cue_lines = []

      lines.each do |line|
        # Skip empty lines at the beginning or between cues
        if line.empty?
          if current_cue && cue_lines.any?
            text = cue_lines.join(" ").gsub(/<[^>]*>/, "").strip # Remove HTML tags
            transcript.add_cue(Cue.new(start_time: current_cue[:start], end_time: current_cue[:end], text: text))
            current_cue = nil
            cue_lines = []
          end
          next
        end

        # Skip WEBVTT header and metadata
        next if line.start_with?("WEBVTT")
        next if line.start_with?("Kind:")
        next if line.start_with?("Language:")
        next if line.start_with?("NOTE")
        next if line.match?(/^\d+$/) # Skip cue numbers

        content_started = true

        # Parse timestamp line (00:00:00.000 --> 00:00:05.000)
        if line.include?("-->")
          # Extract timestamps, ignoring any position/alignment info after
          match = line.match(/(\d{2}:\d{2}:\d{2}[.,]\d{3})\s*-->\s*(\d{2}:\d{2}:\d{2}[.,]\d{3})/)
          if match
            current_cue = {
              start: match[1].tr(",", "."),
              end: match[2].tr(",", ".")
            }
          end
        elsif current_cue
          # This is a text line
          cue_lines << line
        end
      end

      # Add the last cue if present
      if current_cue && cue_lines.any?
        text = cue_lines.join(" ").gsub(/<[^>]*>/, "").strip
        transcript.add_cue(Cue.new(start_time: current_cue[:start], end_time: current_cue[:end], text: text))
      end

      transcript
    end

    def create_from_youtube_transcript(youtube_transcript)
      transcript = Transcript.new
      snippets = youtube_transcript.snippets || []
      snippets.each do |snippet|
        start_time = (snippet.start * 1000).to_i
        end_time = ((snippet.start + snippet.duration) * 1000).to_i
        text = snippet.text
        transcript.add_cue(Cue.new(start_time: start_time, end_time: end_time, text: text))
      end
      transcript
    end

    def create_from_json(json)
      transcript = Transcript.new
      json.map(&:symbolize_keys!)
      json.each do |cue_hash|
        transcript.add_cue(Cue.new(start_time: cue_hash[:start_time], end_time: cue_hash[:end_time], text: cue_hash[:text]))
      end
      transcript
    end

    def format_time(ms)
      hours = ms / (1000 * 60 * 60)
      minutes = (ms % (1000 * 60 * 60)) / (1000 * 60)
      seconds = (ms % (1000 * 60)) / 1000
      milliseconds = ms % 1000
      format("%02d:%02d:%02d.%03d", hours, minutes, seconds, milliseconds)
    end
  end
end
