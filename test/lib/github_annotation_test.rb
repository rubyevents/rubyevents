require "test_helper"

class GitHubAnnotationTest < ActiveSupport::TestCase
  test "error builds an error command" do
    assert_equal "::error file=app/foo.rb,line=3::Broken", GitHubAnnotation.error("Broken", file: "app/foo.rb", line: 3)
  end

  test "warning builds a warning command" do
    assert_equal "::warning file=app/foo.rb,line=3::Suspicious", GitHubAnnotation.warning("Suspicious", file: "app/foo.rb", line: 3)
  end

  test "omits nil properties" do
    assert_equal "::error line=3::Broken", GitHubAnnotation.error("Broken", file: nil, line: 3)
  end

  test "escapes percent signs and line breaks in the message" do
    assert_equal "::error file=a.rb::100%25%0D%0Asure", GitHubAnnotation.error("100%\r\nsure", file: "a.rb")
  end

  test "keeps colons and commas in the message" do
    assert_equal "::error file=a.rb::a: b, c", GitHubAnnotation.error("a: b, c", file: "a.rb")
  end

  test "escapes colons and commas in properties" do
    assert_equal "::error title=Foo%3A%3ABar%2C baz::Broken", GitHubAnnotation.error("Broken", title: "Foo::Bar, baz")
  end
end
