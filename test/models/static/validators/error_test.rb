# frozen_string_literal: true

require "test_helper"

class Static::Validators::ErrorTest < ActiveSupport::TestCase
  test "strips Rails.root from the file path" do
    error = build_error("Something broke")

    assert_equal "data/helveticruby/helveticruby-2025/event.yml", error.file_path
  end

  test "defaults line, end_line, column and end_column to 1" do
    error = build_error("Something broke")

    assert_equal 1, error.line
    assert_equal 1, error.end_line
    assert_equal 1, error.column
    assert_equal 1, error.end_column
  end

  test "uses explicit line, end_line, column and end_column values" do
    error = build_error("Something broke", line: 4, end_line: 6, column: 2, end_column: 10)

    assert_equal 4, error.line
    assert_equal 6, error.end_line
    assert_equal 2, error.column
    assert_equal 10, error.end_column
  end

  test "derives location values from a Yerba::Location" do
    location = yerba_location(start_line: 3, start_column: 2, end_line: 5, end_column: 8)

    error = build_error("Something broke", location: location)

    assert_equal 3, error.line
    assert_equal 5, error.end_line
    assert_equal 2, error.column
    assert_equal 8, error.end_column
  end

  test "explicit values take precedence over the location" do
    location = yerba_location(start_line: 3, start_column: 2, end_line: 5, end_column: 8)

    error = build_error("Something broke", location: location, line: 99, column: 42)

    assert_equal 99, error.line
    assert_equal 5, error.end_line
    assert_equal 42, error.column
    assert_equal 8, error.end_column
  end

  test "to_h returns a hash with string keys" do
    error = build_error("Something broke", line: 2, end_line: 3, column: 4, end_column: 5)

    assert_equal({
      "message" => "Something broke",
      "file_path" => "data/helveticruby/helveticruby-2025/event.yml",
      "line" => 2,
      "end_line" => 3,
      "column" => 4,
      "end_column" => 5
    }, error.to_h)
  end

  test "as_error without GITHUB_ACTIONS uses a plain prefix on line 1" do
    with_github_actions("false") do
      error = build_error("Something broke")

      assert_equal "❌ Something broke", error.as_error
    end
  end

  test "as_error without GITHUB_ACTIONS includes the line number past line 1" do
    with_github_actions("false") do
      error = build_error("Something broke", line: 12)

      assert_equal "❌ line 12: Something broke", error.as_error
    end
  end

  test "as_error with GITHUB_ACTIONS emits a GitHub error annotation" do
    with_github_actions("true") do
      error = build_error("Something broke", line: 2, end_line: 4, column: 3, end_column: 9)

      assert_equal "::error file=data/helveticruby/helveticruby-2025/event.yml,line=2,endLine=4,col=3,endColumn=9:: Something broke", error.as_error
    end
  end

  test "as_warning without GITHUB_ACTIONS uses a plain prefix on line 1" do
    with_github_actions("false") do
      error = build_error("Something suspicious")

      assert_equal "⚠️  Something suspicious", error.as_warning
    end
  end

  test "as_warning without GITHUB_ACTIONS includes the line number past line 1" do
    with_github_actions("false") do
      error = build_error("Something suspicious", line: 7)

      assert_equal "⚠️ line 7:  Something suspicious", error.as_warning
    end
  end

  test "as_warning with GITHUB_ACTIONS emits a GitHub warning annotation" do
    with_github_actions("true") do
      error = build_error("Something suspicious", line: 2, end_line: 4, column: 3, end_column: 9)

      assert_equal "::warning file=data/helveticruby/helveticruby-2025/event.yml,line=2,endLine=4,col=3,endColumn=9::  Something suspicious", error.as_warning
    end
  end

  private

  def with_github_actions(value)
    original = ENV.method(:[])

    ENV.stub(:[], ->(key) { (key == "GITHUB_ACTIONS") ? value : original.call(key) }) do
      yield
    end
  end

  def build_error(message, file_path: Rails.root.join("data/helveticruby/helveticruby-2025/event.yml").to_s, **kwargs)
    Static::Validators::Error.new(message, file_path: file_path, **kwargs)
  end

  def yerba_location(start_line: 1, start_column: 1, end_line: 1, end_column: 1, start_offset: 0, end_offset: 0)
    Yerba::Location.new(start_line:, start_column:, end_line:, end_column:, start_offset:, end_offset:)
  end
end
