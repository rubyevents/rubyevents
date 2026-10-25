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
    @data_changes = Announcement::DataChanges.new(month: Date.new(2026, 9, 1), ref: "main", repository_path: @repository)
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

  private

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
