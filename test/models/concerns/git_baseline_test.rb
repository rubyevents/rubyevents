# frozen_string_literal: true

require "test_helper"

class GitBaselineTest < ActiveSupport::TestCase
  class Host
    include GitBaseline

    def initialize(file_path, baseline: nil)
      @file_path = file_path
      @baseline = baseline
    end
  end

  VIDEOS_PATH = "data/testconf/testconf-2024/videos.yml"

  teardown do
    Host.reset!
  end

  test "baseline_ref returns the commit ref for origin/main or main" do
    stub_merge_base("origin/main" => "orimco", "main" => "mainco") do
      assert_equal "orimco", Host.baseline_ref
    end
  end

  test "baseline_ref falls back to main when origin/main cannot be resolved" do
    stub_merge_base("main" => "def456") do
      assert_equal "def456", Host.baseline_ref
    end
  end

  test "baseline_ref is nil when neither origin/main nor main resolve" do
    stub_merge_base({}) do
      assert_nil Host.baseline_ref
    end
  end

  test "baseline_ref ignores an empty merge-base even when git succeeds" do
    stub_git(["merge-base", "HEAD", "origin/main"] => "") do
      assert_nil Host.baseline_ref
    end
  end

  test "baseline_file parses the file content at the baseline ref" do
    content = [{"id" => "jane-doe-testconf-2024", "title" => "Building Things"}].to_yaml

    stub_git(
      ["merge-base", "HEAD", "origin/main"] => "abc123\n",
      ["show", "abc123:#{VIDEOS_PATH}"] => content
    ) do
      file = Host.baseline_file(VIDEOS_PATH)

      assert_instance_of Yerba::Document, file
      assert_equal "Building Things", file.find_by("id" => "jane-doe-testconf-2024").value_at("title")
    end
  end

  test "baseline_file returns nil when git cannot show the file" do
    stub_git(["merge-base", "HEAD", "origin/main"] => "abc123\n") do
      assert_nil Host.baseline_file(VIDEOS_PATH)
    end
  end

  test "baseline_file returns nil without a baseline ref" do
    stub_git({}) do
      assert_nil Host.baseline_file(VIDEOS_PATH)
    end
  end

  test "changed_paths lists every path changed against the baseline" do
    output = "data/railsconf/2024/videos.yml\ndata/railsconf/2024/event.yml\ndata/euruko/2025/videos.yml\n"

    stub_git(
      ["merge-base", "HEAD", "origin/main"] => "abc123\n",
      ["diff", "--name-only", "abc123", "--", "data"] => output
    ) do
      expected = Set.new(["data/railsconf/2024/videos.yml", "data/railsconf/2024/event.yml", "data/euruko/2025/videos.yml"])
      assert_equal expected, Host.changed_paths
    end
  end

  test "changed_paths is nil when git diff fails" do
    stub_git(["merge-base", "HEAD", "origin/main"] => "abc123\n") do
      assert_nil Host.changed_paths
    end
  end

  test "changed_paths is nil without a baseline ref" do
    stub_git({}) do
      assert_nil Host.changed_paths
    end
  end

  test "warmup precomputes changed_paths" do
    stub_git(
      ["merge-base", "HEAD", "origin/main"] => "abc123\n",
      ["diff", "--name-only", "abc123", "--", "data"] => "data/railsconf/2024/videos.yml\n"
    ) do
      assert_equal Set.new(["data/railsconf/2024/videos.yml"]), Host.warmup
    end
  end

  test "reset! clears memoized baseline_ref" do
    git_output = "one\n"

    Host.stub(:git, ->(*args) {
      (args == ["merge-base", "HEAD", "origin/main"]) ? [git_output, true] : ["", false]
    }) do
      assert_equal "one", Host.baseline_ref

      git_output = "two\n"
      assert_equal "one", Host.baseline_ref, "baseline_ref is memoized"

      Host.reset!

      assert_equal "two", Host.baseline_ref, "baseline_ref is recomputed after reset!"
    end
  end

  test "git returns the output and success flag" do
    status = Struct.new(:success?).new(true)

    Open3.stub(:capture3, ->(*_args) { ["abc123\n", "", status] }) do
      output, success = Host.git("merge-base", "HEAD", "origin/main")

      assert_equal "abc123\n", output
      assert success
    end
  end

  test "git returns failure when git is unavailable" do
    Open3.stub(:capture3, ->(*) { raise Errno::ENOENT }) do
      assert_equal ["", false], Host.git("merge-base", "HEAD", "origin/main")
    end
  end

  test "relative_path strips the Rails root from the file path" do
    host = Host.new(Rails.root.join(VIDEOS_PATH).to_s)

    assert_equal VIDEOS_PATH, host.send(:relative_path)
  end

  test "baseline memoizes the class baseline_file lookup" do
    content = [{"id" => "jane-doe-testconf-2024"}].to_yaml
    show_calls = 0

    Host.stub(:git, ->(*args) {
      case args
      when ["merge-base", "HEAD", "origin/main"]
        ["abc123\n", true]
      when ["show", "abc123:#{VIDEOS_PATH}"]
        show_calls += 1
        [content, true]
      else
        ["", false]
      end
    }) do
      host = Host.new(Rails.root.join(VIDEOS_PATH).to_s)

      assert_instance_of Yerba::Document, host.send(:baseline)
      assert_same host.send(:baseline), host.send(:baseline)
      assert_equal 1, show_calls, "the baseline file is only fetched once"
    end
  end

  test "changed_since_baseline? is true when a baseline is injected" do
    baseline = Static::VideosFile.parse([{"id" => "x"}].to_yaml)
    host = Host.new(Rails.root.join(VIDEOS_PATH).to_s, baseline: baseline)

    assert host.send(:changed_since_baseline?)
  end

  test "changed_since_baseline? is true when changed_paths cannot be determined" do
    host = Host.new(Rails.root.join(VIDEOS_PATH).to_s)

    stub_git({}) do
      assert host.send(:changed_since_baseline?)
    end
  end

  test "changed_since_baseline? is true when the file is among the changed paths" do
    host = Host.new(Rails.root.join(VIDEOS_PATH).to_s)

    stub_git(
      ["merge-base", "HEAD", "origin/main"] => "abc123\n",
      ["diff", "--name-only", "abc123", "--", "data"] => "#{VIDEOS_PATH}\n"
    ) do
      assert host.send(:changed_since_baseline?)
    end
  end

  test "changed_since_baseline? is false when the file is not among the changed paths" do
    host = Host.new(Rails.root.join(VIDEOS_PATH).to_s)

    stub_git(
      ["merge-base", "HEAD", "origin/main"] => "abc123\n",
      ["diff", "--name-only", "abc123", "--", "data"] => "data/other/2025/videos.yml\n"
    ) do
      assert_not host.send(:changed_since_baseline?)
    end
  end

  private

  def stub_merge_base(branches, &block)
    results = branches.to_h { |branch, commit| [["merge-base", "HEAD", branch], commit] }

    stub_git(results, &block)
  end

  def stub_git(results, &block)
    Host.stub(:git, ->(*args) {
      [results[args], results.key?(args)]
    }, &block)
  end
end
