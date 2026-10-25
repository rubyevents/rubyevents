# frozen_string_literal: true

require "open3"

# Summarizes the data added to data/ during a month as newsletter markdown, by
# loading each changed file before and after a commit through its Static model.
#
# Every squash-merged commit on main is one PR, so each change is credited to
# the PR number from the commit subject, or to the commit SHA for direct pushes.
#
class Announcement::DataChanges
  REPOSITORY_URL = "https://github.com/rubyevents/rubyevents"

  Entry = Struct.new(:event, :count, :commits, keyword_init: true)

  attr_reader :month, :ref, :repository_path

  def initialize(month:, ref: nil, repository_path: Rails.root)
    @month = month.beginning_of_month
    @repository_path = repository_path.to_s
    @ref = ref || default_ref
    @sections = Hash.new { |hash, key| hash[key] = {} }
    @new_speakers = []
  end

  def commits
    @commits ||= begin
      output = git!("log", "--first-parent", "--format=%H%x1f%an%x1f%ae%x1f%ct%x1f%s",
        "--since=#{month.beginning_of_day.iso8601}", "--until=#{month.next_month.beginning_of_day.iso8601}", ref)

      output.lines.map do |line|
        sha, author, email, time, subject = line.chomp.split("\x1f", 5)

        Yerba::Record::Commit.new(sha: sha, author: author, email: email, date: Time.zone.at(time.to_i), subject: subject)
      end
    end
  end

  def collect
    commits.reverse_each do |commit|
      files = with_moved_directories(commit, changed_files(commit))
      @before_talks = before_talks(commit, files)

      files.each { |status, before_path, after_path| collect_file(commit, status, before_path, after_path) }
    end

    @collected = true
    self
  end

  def videos_markdown
    collect unless @collected

    lines(:videos) { |entry| "📺 #{entry.count} #{"video".pluralize(entry.count)} published for #{event_link(entry.event, "talks")} in #{credits(entry)}" }.join("\n")
  end

  def new_data_markdown
    collect unless @collected

    [
      section("New events", :events) { |entry| "📆 #{event_link(entry.event)}#{event_details(entry.event)} added in #{credits(entry)}" },
      section("New talks", :talks) { |entry| "🎤 #{entry.count} #{"talk".pluralize(entry.count)} added to #{event_link(entry.event, "talks")} in #{credits(entry)}" },
      section("Schedules", :schedules) { |entry| "🗓️ #{event_link(entry.event, "schedule")} schedule added in #{credits(entry)}" },
      section("CFPs", :cfps) { |entry| "📣 #{entry.count} #{"CFP".pluralize(entry.count)} added to #{event_link(entry.event, "cfp")} in #{credits(entry)}" },
      section("Sponsors", :sponsors) { |entry| "🤝 #{entry.count} #{"sponsor".pluralize(entry.count)} added to #{event_link(entry.event, "sponsors")} in #{credits(entry)}" },
      section("Venues", :venues) { |entry| "📍 #{event_link(entry.event, "venue")} venue added in #{credits(entry)}" },
      section("Involvements", :involvements) { |entry| "🙌 #{entry.count} #{"involvement".pluralize(entry.count)} added to #{event_link(entry.event)} in #{credits(entry)}" },
      speakers_section
    ].compact.join("\n\n")
  end

  private

  def collect_file(commit, status, before_path, after_path)
    return if status == "D"

    case File.basename(after_path)
    when "event.yml"
      collect_event(commit, status, after_path)
    when "videos.yml"
      collect_talks(commit, after_path)
    when "schedule.yml"
      record(:schedules, commit, after_path, 1) if status == "A"
    when "venue.yml"
      record(:venues, commit, after_path, 1) if status == "A"
    when "cfp.yml"
      record(:cfps, commit, after_path, new_records(commit, before_path, after_path) { |path, revision| load(Static::CFP, revision, path).map { |cfp| [cfp.link, cfp.name] } })
    when "sponsors.yml"
      record(:sponsors, commit, after_path, new_records(commit, before_path, after_path) { |path, revision| sponsor_entries(revision, path).map { |sponsor| [sponsor.slug, sponsor.name] } })
    when "involvements.yml"
      record(:involvements, commit, after_path, new_records(commit, before_path, after_path) { |path, revision| load(Static::Involvement, revision, path).map { |involvement| [involvement.name] } })
    when "speakers.yml"
      collect_speakers(commit, before_path, after_path)
    end
  end

  def collect_event(commit, status, path)
    return unless status == "A"

    event = load(Static::Event, commit.sha, path).first
    return if event.nil? || event.old_ids.present?

    record(:events, commit, path, 1)
  end

  def collect_talks(commit, after_path)
    published = 0
    added = 0

    load(Static::Talk, commit.sha, after_path).each do |talk|
      previous = @before_talks[talk.id] || @before_talks[talk.old_id]

      if Talk::WATCHABLE_PROVIDERS.include?(talk.video_provider)
        published += 1 unless previous && Talk::WATCHABLE_PROVIDERS.include?(previous.video_provider)
      elsif previous.nil? && Talk::UNPUBLISHED_PROVIDERS.include?(talk.video_provider)
        added += 1
      end
    end

    record(:videos, commit, after_path, published)
    record(:talks, commit, after_path, added)
  end

  def with_moved_directories(commit, files)
    removed = files.each_with_object({}) do |(status, before_path, _), directories|
      next unless status == "D" && File.basename(before_path) == "event.yml"

      event = load(Static::Event, "#{commit.sha}^", before_path).first
      directories[event.id] = File.dirname(before_path) if event
    end

    return files if removed.empty?

    files.map do |status, before_path, after_path|
      next [status, before_path, after_path] unless status == "A"

      moved_from = moved_from(commit, File.dirname(after_path), removed)
      moved_from ? ["M", File.join(moved_from, File.basename(after_path)), after_path] : [status, before_path, after_path]
    end
  end

  def moved_from(commit, directory, removed)
    event = load(Static::Event, commit.sha, File.join(directory, "event.yml")).first

    event && [event.id, *event.old_ids].filter_map { |id| removed[id] }.first
  end

  def before_talks(commit, files)
    files.select { |status, before_path, _| status != "A" && File.basename(before_path) == "videos.yml" }
      .flat_map { |_, before_path, _| load(Static::Talk, "#{commit.sha}^", before_path).to_a }
      .index_by(&:id)
  end

  def collect_speakers(commit, before_path, after_path)
    existing = load(Static::Speaker, "#{commit.sha}^", before_path).flat_map { |speaker| speaker_identifiers(speaker) }.to_set

    load(Static::Speaker, commit.sha, after_path).each do |speaker|
      @new_speakers << [speaker, commit] if speaker_identifiers(speaker).none? { |identifier| existing.include?(identifier) }
    end
  end

  def speaker_identifiers(speaker)
    [speaker.name, speaker.slug, speaker.github.presence&.downcase].compact
  end

  def new_records(commit, before_path, after_path, &identifiers)
    before = identifiers.call(before_path, "#{commit.sha}^").flatten.compact.to_set

    identifiers.call(after_path, commit.sha).count { |keys| keys.compact.none? { |key| before.include?(key) } }
  end

  def sponsor_entries(revision, path)
    load(Static::Sponsor, revision, path).flat_map { |sponsor| sponsor.tiers.flat_map { |tier| tier.sponsors.to_a } }
  end

  def record(section, commit, path, count)
    return if count.zero?

    event = event_for(commit, File.dirname(path))
    return if event.nil?

    entry = @sections[section][event.id] ||= Entry.new(event: event, count: 0, commits: [])
    entry.count += count
    entry.commits |= [commit]
  end

  def event_for(commit, directory)
    @events ||= {}
    @events[[commit.sha, directory]] ||= load(Static::Event, commit.sha, File.join(directory, "event.yml")).first&.then do |event|
      current_events[event.id] || event
    end
  end

  def current_events
    @current_events ||= Static::Event.all.each_with_object({}) do |event, index|
      [event.id, *event.old_ids].each { |id| index[id] ||= event }
    end
  end

  def lines(key, &block)
    @sections[key].values.sort_by { |entry| entry.event.start_date.to_s }.map(&block)
  end

  def section(title, key, &block)
    entries = lines(key, &block)
    return if entries.empty?

    "### #{title}\n\n#{entries.join("\n")}"
  end

  def speakers_section
    return if @new_speakers.empty?

    credits = @new_speakers.map(&:last).uniq.map { |commit| credit(commit) }.to_sentence

    "### New speakers\n\n🗣️ #{@new_speakers.size} new #{"speaker".pluralize(@new_speakers.size)} added in #{credits}"
  end

  def event_link(event, page = nil)
    "[#{event.title}](#{["/events", event.id, page].compact.join("/")})"
  end

  def event_details(event)
    details = [format_dates(event.start_date, event.end_date), event.location.presence].compact.join(" in ")

    details.present? ? "(#{details})" : ""
  end

  def format_dates(start_date, end_date)
    return unless start_date.is_a?(Date)

    end_date = start_date unless end_date.is_a?(Date)

    if start_date == end_date
      start_date.strftime("%B %d, %Y")
    elsif start_date.month == end_date.month && start_date.year == end_date.year
      "#{start_date.strftime("%B %d")}-#{end_date.strftime("%d, %Y")}"
    else
      "#{start_date.strftime("%B %d")} - #{end_date.strftime("%B %d, %Y")}"
    end
  end

  def credits(entry)
    entry.commits.map { |commit| credit(commit) }.to_sentence
  end

  def credit(commit)
    if commit.pr_number
      "PR [#{commit.pr_number}](#{REPOSITORY_URL}/pull/#{commit.pr_number})"
    else
      "commit [#{commit.short_sha}](#{REPOSITORY_URL}/commit/#{commit.sha})"
    end
  end

  def changed_files(commit)
    @changed_files ||= {}
    @changed_files[commit.sha] ||= git!("diff-tree", "-r", "-M", "--no-commit-id", "--name-status", commit.sha, "--", "data").lines.map do |line|
      status, *paths = line.chomp.split("\t")
      [status[0], paths.first, paths.last]
    end
  end

  def load(model, revision, path)
    content, _stderr, status = git("show", "#{revision}:#{path}")
    return [] unless status.success? && content.present?

    model.parse(content, path: path)
  end

  def default_ref
    %w[origin/main main].find { |branch| git("rev-parse", "--verify", "--quiet", branch).last.success? }
  end

  def git(*arguments)
    Open3.capture3("git", *arguments, chdir: repository_path)
  end

  def git!(*arguments)
    output, stderr, status = git(*arguments)
    raise "git #{arguments.join(" ")} failed: #{stderr}" unless status.success?

    output
  end
end
