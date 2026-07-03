class Talk::Transcript::CueList < Data.define(:cues)
  include Enumerable

  def to_text
    cues.map(&:text).join("\n\n")
  end

  def to_vtt
    vtt_content = "WEBVTT\n\n"

    cues.each_with_index do |cue, index|
      vtt_content += "#{index + 1}\n"
      vtt_content += "#{cue}\n\n"
    end

    vtt_content
  end

  def presence
    cues.any? ? self : nil
  end

  def present?
    cues.any?
  end

  def each(&)
    cues.each(&)
  end

  def slice(from_seconds, to_seconds)
    self.class.new(cues: cues.select { |cue| cue.start_time_in_seconds.between?(from_seconds, to_seconds) })
  end

  class << self
    def from_youtube(youtube_transcript)
      cues = Array.wrap(youtube_transcript.snippets).map do |snippet|
        Talk::Transcript::Cue.new(
          start_time: format_time((snippet.start * 1000).to_i),
          end_time: format_time(((snippet.start + snippet.duration) * 1000).to_i),
          text: snippet.text
        )
      end

      new(cues:)
    end

    def from_json(json)
      cues = json.map do |cue_hash|
        cue_hash = cue_hash.symbolize_keys

        Talk::Transcript::Cue.new(
          start_time: cue_hash[:start_time],
          end_time: cue_hash[:end_time],
          text: cue_hash[:text]
        )
      end

      new(cues:)
    end

    def format_time(ms)
      seconds, milliseconds = ms.divmod(1000)
      minutes, seconds = seconds.divmod(60)
      hours, minutes = minutes.divmod(60)

      format("%02d:%02d:%02d.%03d", hours, minutes, seconds, milliseconds)
    end
  end
end
