class GitHubAnnotation
  def self.error(message, **properties)
    command("error", message, properties)
  end

  def self.warning(message, **properties)
    command("warning", message, properties)
  end

  def self.command(level, message, properties)
    formatted_properties = properties.compact.map { |key, value| "#{key}=#{escape_property(value)}" }.join(",")

    "::#{level} #{formatted_properties}::#{escape_data(message)}"
  end

  def self.escape_data(value)
    value.to_s.gsub("%", "%25").gsub("\r", "%0D").gsub("\n", "%0A")
  end

  def self.escape_property(value)
    escape_data(value).gsub(":", "%3A").gsub(",", "%2C")
  end
end
