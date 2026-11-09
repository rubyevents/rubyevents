class GitHubAnnotationsReporter < Minitest::Reporter
  ANSI_ESCAPE = /\e\[[0-9;]*m/
  LOCATION = /\A(.+):(\d+)\z/

  def self.minitest_plugin_init(options)
    return unless ENV["GITHUB_ACTIONS"] == "true"

    Minitest.reporter << new(options[:io], options)
  end

  def initialize(...)
    super
    @annotations = []
  end

  def record(result)
    result.failures.grep_v(Minitest::Skip).each do |failure|
      @annotations << annotation(result, failure)
    end
  end

  def report
    return if @annotations.empty?

    io.puts
    io.puts @annotations
  end

  private

  def annotation(result, failure)
    file, line = workspace_location(failure.location) || workspace_location(result.source_location.join(":"))
    message = failure.message.gsub(ANSI_ESCAPE, "").strip

    GitHubAnnotation.error(message, file: file, line: line, title: "#{result.klass}##{result.name}")
  end

  def workspace_location(location)
    path, line = location.match(LOCATION)&.captures
    return unless path

    absolute_path = File.expand_path(path, Rails.root)
    relative_path = absolute_path.delete_prefix("#{Rails.root}/")

    return if relative_path == absolute_path || relative_path.start_with?("vendor/") || !File.file?(absolute_path)

    [relative_path, line]
  end
end
