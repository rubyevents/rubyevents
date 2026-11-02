require "test_helper"

class Yerba::Record::HistoryTest < ActiveSupport::TestCase
  setup do
    @repository = Dir.mktmpdir("history", Rails.root.join("tmp").to_s)
    @path = File.join(@repository, "videos.yml")
    git "init", "--quiet"

    File.write(@path, <<~YAML)
      ---
      - id: "talk-a"
        title: "Talk A"
        video_provider: "scheduled"
    YAML
    commit "Add Talk A (#1)", date: "2026-08-15T12:00:00Z"

    File.write(@path, <<~YAML)
      ---
      - id: "talk-a"
        title: "Talk A"
        video_provider: "youtube"

      - id: "talk-b"
        title: "Talk B"
        video_provider: "youtube"
    YAML
    commit "Publish Talk A and add Talk B", date: "2026-09-20T12:00:00Z"
  end

  teardown do
    Yerba::Record::Blame.reset!
    FileUtils.remove_entry(@repository)
  end

  test "created_at and updated_at come from the oldest and newest commit of the record's lines" do
    talk = talks.find_by(id: "talk-a")

    assert_equal Time.utc(2026, 8, 15, 12), talk.created_at
    assert_equal Time.utc(2026, 9, 20, 12), talk.updated_at
    assert_equal ["Add Talk A (#1)", "Publish Talk A and add Talk B"], talk.commits.map(&:subject)
  end

  test "commit is the last commit and knows its pull request" do
    talk = talks.find_by(id: "talk-a")

    assert_equal "Publish Talk A and add Talk B", talk.commit.subject
    assert_nil talk.commit.pr_number
    assert_equal 1, talk.first_commit.pr_number
    assert_equal "Test", talk.commit.author
    assert_equal "test@example.com", talk.commit.email
  end

  test "commit_for returns the last commit that changed a field" do
    talk = talks.find_by(id: "talk-a")

    assert_equal "Add Talk A (#1)", talk.commit_for(:title).subject
    assert_equal "Publish Talk A and add Talk B", talk.commit_for(:video_provider).subject
  end

  test "where filters by created_at and by the commit" do
    assert_equal ["talk-b"], talks.where(created_at: Date.new(2026, 9, 1)..Date.new(2026, 9, 30)).map(&:id)
    assert_equal ["talk-a"], talks.where(first_commit: {pr_number: 1}).map(&:id)
    assert_equal %w[talk-a talk-b], talks.where(updated_at: Date.new(2026, 9, 1)..).map(&:id)
  end

  test "where with a Date range covers commits on its last day" do
    File.write(@path, File.read(@path) + <<~YAML)

      - id: "talk-c"
        title: "Talk C"
        video_provider: "youtube"
    YAML
    commit "Add Talk C", date: "2026-09-30T15:00:00Z"

    assert_equal %w[talk-b talk-c], talks.where(created_at: Date.new(2026, 9, 1).all_month).map(&:id)
    assert_equal ["talk-c"], talks.where(created_at: Date.new(2026, 9, 30)..Date.new(2026, 9, 30)).map(&:id)
  end

  test "lines that aren't committed yet are skipped" do
    File.write(@path, File.read(@path) + <<~YAML)

      - id: "talk-c"
        title: "Talk C"
        video_provider: "youtube"
    YAML

    talk = talks.find_by(id: "talk-c")

    assert_empty talk.commits
    assert_nil talk.commit
    assert_nil talk.created_at
  end

  test "records parsed from a string have no history" do
    talk = Static::Talk.parse(File.read(@path), path: "data/demo/demo-2026/videos.yml").first

    assert_nil talk.commit
    assert_nil talk.updated_at
  end

  private

  def talks
    Static::Talk.in_file(@path)
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
