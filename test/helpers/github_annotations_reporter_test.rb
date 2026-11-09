require "test_helper"

class GitHubAnnotationsReporterTest < ActiveSupport::TestCase
  setup do
    @io = StringIO.new
    @reporter = GitHubAnnotationsReporter.new(@io)
  end

  test "reports a failed assertion at the line of the assertion" do
    @reporter.record(result(failure("Expected true", "test/test_helper.rb:12:in 'block'")))
    @reporter.report

    assert_equal "\n::error file=test/test_helper.rb,line=12,title=Foo%3A%3ABarTest#test_baz::Expected true\n", @io.string
  end

  test "reports unexpected errors with their class and message" do
    error = RuntimeError.new("boom")
    error.set_backtrace(["test/test_helper.rb:5:in 'block'"])

    @reporter.record(result(Minitest::UnexpectedError.new(error)))
    @reporter.report

    assert_includes @io.string, "file=test/test_helper.rb,line=5,"
    assert_includes @io.string, "::RuntimeError: boom"
  end

  test "reports every failure of a test" do
    @reporter.record(result(failure("first", "test/test_helper.rb:1"), failure("second", "test/test_helper.rb:2")))
    @reporter.report

    assert_equal 2, @io.string.scan("::error ").size
  end

  test "ignores skips and passes" do
    @reporter.record(result(Minitest::Skip.new("later")))
    @reporter.record(result)
    @reporter.report

    assert_empty @io.string
  end

  test "escapes newlines and percent signs in the message" do
    @reporter.record(result(failure("100%\nsure", "test/test_helper.rb:1")))
    @reporter.report

    assert_includes @io.string, "::100%25%0Asure\n"
  end

  test "strips ANSI colors from the message" do
    @reporter.record(result(failure("\e[31;1mred\e[0m", "test/test_helper.rb:1")))
    @reporter.report

    assert_includes @io.string, "::red\n"
  end

  test "falls back to the test definition when the failure is outside of the workspace" do
    @reporter.record(result(failure("nope", "/usr/lib/ruby/gems/foo.rb:9")))
    @reporter.report

    assert_includes @io.string, "file=test/test_helper.rb,line=42,"
  end

  test "falls back to the test definition when the failure is in a vendored gem" do
    @reporter.record(result(failure("nope", Rails.root.join("vendor/bundle/foo.rb:9").to_s)))
    @reporter.report

    assert_includes @io.string, "file=test/test_helper.rb,line=42,"
  end

  test "omits the location when neither location can be resolved" do
    test_result = result(failure("nope", "/usr/lib/ruby/gems/foo.rb:9"))
    test_result.source_location = ["unknown", -1]

    @reporter.record(test_result)
    @reporter.report

    assert_includes @io.string, "::error title=Foo%3A%3ABarTest#test_baz::nope\n"
  end

  test "only registers itself on GitHub Actions" do
    reporter = Minitest::CompositeReporter.new

    Minitest.stub(:reporter, reporter) do
      with_github_actions(nil) { GitHubAnnotationsReporter.minitest_plugin_init(io: @io) }
      assert_empty reporter.reporters

      with_github_actions("true") { GitHubAnnotationsReporter.minitest_plugin_init(io: @io) }
      assert_instance_of GitHubAnnotationsReporter, reporter.reporters.sole
    end
  end

  private

  def result(*failures)
    Minitest::Result.new("test_baz").tap do |result|
      result.klass = "Foo::BarTest"
      result.failures = failures
      result.source_location = [Rails.root.join("test/test_helper.rb").to_s, 42]
    end
  end

  def failure(message, *backtrace)
    Minitest::Assertion.new(message).tap { |assertion| assertion.set_backtrace(backtrace) }
  end

  def with_github_actions(value)
    original = ENV["GITHUB_ACTIONS"]
    ENV["GITHUB_ACTIONS"] = value
    yield
  ensure
    ENV["GITHUB_ACTIONS"] = original
  end
end
