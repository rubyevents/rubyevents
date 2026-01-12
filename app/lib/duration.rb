class Duration
  def self.seconds_to_formatted_duration(seconds, raise: true)
    if seconds.is_a?(Integer)
      parts = ActiveSupport::Duration.build(seconds).parts
    elsif seconds.is_a?(ActiveSupport::Duration)
      parts = seconds.parts
    else
      raise "seconds (`#{seconds.inspect}`) is not an Integer or ActiveSupport::Duration" if raise
      return "??:??"
    end

    values = [
      parts.fetch(:hours, nil),
      parts.fetch(:minutes, 0),
      parts.fetch(:seconds, 0)
    ].compact

    return "??:??" if values.any?(&:negative?)

    values.map { |value| value.to_s.rjust(2, "0") }.join(":")
  end
end
