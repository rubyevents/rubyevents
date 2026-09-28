# frozen_string_literal: true

require "test_helper"

class Static::Validators::ExpectedDataFilesTest < ActiveSupport::TestCase
  test "applicable? returns true for a file under data/" do
    file = Dir.glob(Rails.root.join("data/**/event.yml")).first.to_s
    assert Static::Validators::ExpectedDataFiles.new(file_path: file).applicable?
  end

  test "applicable? returns false for a file outside data/" do
    assert_not Static::Validators::ExpectedDataFiles.new(file_path: __FILE__).applicable?
  end

  test "applicable? returns false for a non-existent file" do
    assert_not Static::Validators::ExpectedDataFiles.new(file_path: "/nonexistent/data/blah.yml").applicable?
  end

  test "does not flag expected files at each level" do
    %w[
      speakers.yml
      testconf/series.yml
      testconf/testconf-2025/event.yml
      testconf/testconf-2025/videos.yml
      testconf/testconf-2025/schedule.yml
      testconf/testconf-2025/venue.yml
      testconf/testconf-2025/cfp.yml
      testconf/testconf-2025/sponsors.yml
      testconf/testconf-2025/involvements.yml
    ].each do |path|
      with_temp_data_file(path) do |file|
        assert_empty Static::Validators::ExpectedDataFiles.new(file_path: file).errors, "expected no errors for #{path}"
      end
    end
  end

  test "flags an unknown file name" do
    with_temp_data_file("testconf/testconf-2025/blah.yml") do |file|
      errors = Static::Validators::ExpectedDataFiles.new(file_path: file).errors

      assert_equal 1, errors.size
      assert_includes errors.first.message, "Unexpected file 'blah.yml'"
      assert_includes errors.first.message, "expected one of: cfp.yml, event.yml"
    end
  end

  test "suggests the correct name for a typo" do
    with_temp_data_file("testconf/testconf-2025/evvvent.yml") do |file|
      assert_includes Static::Validators::ExpectedDataFiles.new(file_path: file).errors.first.message, "did you mean 'event.yml'?"
    end

    with_temp_data_file("testconf/testconf-2025/even.yml") do |file|
      assert_includes Static::Validators::ExpectedDataFiles.new(file_path: file).errors.first.message, "did you mean 'event.yml'?"
    end

    with_temp_data_file("testconf/testconf-2025/involvments.yml") do |file|
      assert_includes Static::Validators::ExpectedDataFiles.new(file_path: file).errors.first.message, "did you mean 'involvements.yml'?"
    end
  end

  test "flags a known file at the wrong nesting level" do
    with_temp_data_file("testconf/series.yml", filename: "event.yml") do |file|
      assert_includes Static::Validators::ExpectedDataFiles.new(file_path: file).errors.first.message,
        "event.yml files belong at data/{series}/{event}/event.yml"
    end

    with_temp_data_file("testconf/testconf-2025/series.yml") do |file|
      assert_includes Static::Validators::ExpectedDataFiles.new(file_path: file).errors.first.message,
        "series.yml files belong at data/{series}/series.yml"
    end
  end

  test "flags files nested too deeply" do
    with_temp_data_file("testconf/testconf-2025/extra/event.yml") do |file|
      assert_includes Static::Validators::ExpectedDataFiles.new(file_path: file).errors.first.message,
        "event.yml files belong at data/{series}/{event}/event.yml"
    end

    with_temp_data_file("testconf/testconf-2025/extra/blah.yml") do |file|
      assert_includes Static::Validators::ExpectedDataFiles.new(file_path: file).errors.first.message,
        "no files are expected at this level"
    end
  end

  test "flags non-yml files" do
    %w[
      testconf/testconf-2025/notes.txt
      testconf/testconf-2025/image.png
      testconf/testconf-2025/script.rb
      testconf/testconf-2025/.DS_Store
      testconf/.DS_Store
      speakers.json
    ].each do |path|
      with_temp_data_file(path) do |file|
        errors = Static::Validators::ExpectedDataFiles.new(file_path: file).errors
        assert_equal 1, errors.size, "expected #{path} to be flagged"
      end
    end
  end

  test "flags yaml extension and suggests the yml equivalent" do
    with_temp_data_file("testconf/testconf-2025/event.yaml") do |file|
      assert_includes Static::Validators::ExpectedDataFiles.new(file_path: file).errors.first.message, "did you mean 'event.yml'?"
    end
  end

  test "returns no errors for all real data files" do
    errors = Dir.glob(Rails.root.join("data/**/*")).select { |file| File.file?(file) }.flat_map do |file|
      Static::Validators::ExpectedDataFiles.new(file_path: file).errors
    end

    assert_empty errors
  end

  private

  def with_temp_data_file(relative_path, filename: nil)
    dir = Dir.mktmpdir
    file_path = File.join(dir, "data", *relative_path.split("/")[0..-2], filename || relative_path.split("/").last)
    FileUtils.mkdir_p(File.dirname(file_path))
    FileUtils.touch(file_path)

    yield file_path
  ensure
    FileUtils.rm_rf(dir)
  end
end
