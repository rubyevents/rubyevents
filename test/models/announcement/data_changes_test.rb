require "test_helper"

class Announcement::DataChangesTest < ActiveSupport::TestCase
  setup do
    @repository = Dir.mktmpdir("data_changes", Rails.root.join("tmp").to_s)
    git "init", "--quiet", "--initial-branch=main"

    write "data/demo/demo-2026/event.yml", <<~YAML
      ---
      id: "demo-2026"
      title: "Demo 2026"
      start_date: "2026-09-10"
      end_date: "2026-09-11"
      location: "Vienna, Austria"
    YAML
    write "data/demo/demo-2026/videos.yml", <<~YAML
      ---
      - id: "talk-a"
        title: "Talk A"
        video_provider: "scheduled"
    YAML
    commit "Add Demo 2026 (#1)", date: "2026-08-15T12:00:00Z"

    write "data/demo/demo-2026/videos.yml", <<~YAML
      ---
      - id: "talk-a"
        title: "Talk A"
        video_provider: "youtube"
      - id: "talk-b"
        title: "Talk B"
        video_provider: "youtube"
      - id: "talk-c"
        title: "Talk C"
        video_provider: "scheduled"
      - id: "talk-d"
        title: "Talk D"
        video_provider: "not_recorded"
    YAML
    write "data/demo/demo-2026/schedule.yml", "---\ndays: []\n"
    commit "Add Demo 2026 videos (#42)", date: "2026-09-20T12:00:00Z"

    write "data/demo/demo-2027/event.yml", <<~YAML
      ---
      id: "demo-2027"
      title: "Demo 2027"
      start_date: "2027-05-03"
      end_date: "2027-05-03"
      location: "Vienna, Austria"
    YAML
    commit "Add Demo 2027", date: "2026-09-25T12:00:00Z"

    @direct_push_sha = git("rev-parse", "HEAD").strip
    @data_changes = data_changes
  end

  teardown do
    FileUtils.remove_entry(@repository)
  end

  test "credits published videos to the PR from the squash commit subject" do
    assert_equal "📺 2 videos published for [Demo 2026](/events/demo-2026/talks) in PR [42](https://github.com/rubyevents/rubyevents/pull/42)", @data_changes.videos_markdown
  end

  test "lists new data and credits direct pushes to the commit" do
    markdown = @data_changes.new_data_markdown

    assert_includes markdown, "📆 [Demo 2027](/events/demo-2027)(May 03, 2027 in Vienna, Austria) added in commit [#{@direct_push_sha[0, 9]}](https://github.com/rubyevents/rubyevents/commit/#{@direct_push_sha})"
    assert_includes markdown, "🎤 2 talks added to [Demo 2026](/events/demo-2026/talks) in PR [42]"
    assert_includes markdown, "🗓️ [Demo 2026](/events/demo-2026/schedule) schedule added in PR [42]"
    assert_not_includes markdown, "[Demo 2026](/events/demo-2026) added"
  end

  test "doesn't count a talk moved to another event's file as added" do
    write "data/demo/demo-2026/videos.yml", <<~YAML
      ---
      - id: "talk-a"
        title: "Talk A"
        video_provider: "youtube"
      - id: "talk-b"
        title: "Talk B"
        video_provider: "youtube"
      - id: "talk-d"
        title: "Talk D"
        video_provider: "not_recorded"
    YAML
    write "data/demo/demo-2027/videos.yml", <<~YAML
      ---
      - id: "talk-c"
        title: "Talk C"
        video_provider: "scheduled"
    YAML
    commit "Move Talk C to Demo 2027 (#43)", date: "2026-09-28T12:00:00Z"

    markdown = data_changes.new_data_markdown

    assert_includes markdown, "🎤 2 talks added to [Demo 2026](/events/demo-2026/talks) in PR [42]"
    assert_not_includes markdown, "[Demo 2027](/events/demo-2027/talks)"
  end

  test "doesn't count an event moved to another directory as new" do
    FileUtils.mkdir_p(File.join(@repository, "data/demo-conf"))
    FileUtils.mv(File.join(@repository, "data/demo/demo-2026"), File.join(@repository, "data/demo-conf/demo-2026"))
    write "data/demo-conf/demo-2026/event.yml", <<~YAML
      ---
      id: "demo-2026"
      title: "Demo Conf 2026"
      description: |-
        The 2026 edition of Demo Conf, moved into its own series.
      kind: "conference"
      timezone: "Europe/Vienna"
      start_date: "2026-09-10T09:00:00"
      end_date: "2026-09-11T18:00:00"
      location: "Wien, Österreich"
      website: "https://demo-conf.example.com"
      tickets_url: "https://demo-conf.example.com/tickets"
      banner_background: "#000000"
      featured_background: "#111111"
      featured_color: "#FFFFFF"
      coordinates:
        latitude: 48.2082
        longitude: 16.3738
    YAML
    commit "Move Demo 2026 into the Demo Conf series (#44)", date: "2026-09-28T12:00:00Z"

    changes = data_changes

    assert_equal "📺 2 videos published for [Demo 2026](/events/demo-2026/talks) in PR [42](https://github.com/rubyevents/rubyevents/pull/42)", changes.videos_markdown
    assert_not_includes changes.new_data_markdown, "/pull/44"
  end

  private

  def data_changes
    Announcement::DataChanges.new(month: Date.new(2026, 9, 1), ref: "main", repository_path: @repository)
  end

  def write(path, content)
    full_path = File.join(@repository, path)
    FileUtils.mkdir_p(File.dirname(full_path))
    File.write(full_path, content)
  end

  def commit(subject, date:)
    git "add", "--all"
    git "-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "--quiet", "-m", subject, env: {"GIT_AUTHOR_DATE" => date, "GIT_COMMITTER_DATE" => date}
  end

  def git(*arguments, env: {})
    output, error, status = Open3.capture3(env, "git", *arguments, chdir: @repository)
    raise "git #{arguments.join(" ")} failed: #{error}" unless status.success?

    output
  end
end
