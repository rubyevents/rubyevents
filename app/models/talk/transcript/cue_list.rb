class Talk::Transcript::CueList < Data.define(:cues)
  include Enumerable

  Passage = Data.define(:start_seconds, :end_seconds, :text)

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

  def deduplicated
    self.class.new(cues: self.class.deduplicate_cues(cues))
  end

  def passages(window: 45)
    groups = []

    cues.each do |cue|
      next if cue.text.blank?

      if groups.empty? || (cue.start_time_in_seconds - groups.last.first.start_time_in_seconds) >= window
        groups << [cue]
      else
        groups.last << cue
      end
    end

    groups.map do |group|
      Passage.new(
        start_seconds: group.first.start_time_in_seconds,
        end_seconds: group.last.end_time_in_seconds,
        text: group.map(&:text).join(" ").squish
      )
    end
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

      new(cues: deduplicate_cues(cues))
    end

    def deduplicate_cues(cues)
      cues.each_with_object([]) do |cue, result|
        text = result.empty? ? cue.text.to_s.strip : strip_overlap(result.last.text, cue.text)
        next if text.blank?

        result << Talk::Transcript::Cue.new(start_time: cue.start_time, end_time: cue.end_time, text: text)
      end
    end

    def strip_overlap(previous, current)
      previous_words = previous.to_s.split
      current_words = current.to_s.split
      limit = [previous_words.size, current_words.size].min

      overlap = limit.downto(1).find { |n| previous_words.last(n) == current_words.first(n) } || 0

      current_words.drop(overlap).join(" ")
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
