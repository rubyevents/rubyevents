class Talk::Transcript::Cue
  attr_reader :start_time, :end_time, :text

  def initialize(start_time:, end_time:, text:)
    @start_time = start_time
    @end_time = end_time
    @text = text || ""
  end

  def to_s
    "#{start_time} --> #{end_time}\n#{text}"
  end

  def to_h
    {
      start_time: start_time,
      end_time: end_time,
      text: text
    }
  end

  def start_time_in_seconds
    time_string_to_seconds(start_time)
  end

  def end_time_in_seconds
    time_string_to_seconds(end_time)
  end

  def time_string_to_seconds(time_string)
    parts = time_string.split(":").map(&:to_f)
    hours = parts[0] * 3600
    minutes = parts[1] * 60
    seconds = parts[2]

    (hours + minutes + seconds).to_i
  rescue
    0
  end

  def sound_descriptor?
    text&.match?(/\[(music|sound|audio|applause|laughter|speech|voice|speeches|voices)\]/i)
  end
end
