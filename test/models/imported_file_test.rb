# frozen_string_literal: true

require "test_helper"

class ImportedFileTest < ActiveSupport::TestCase
  def with_temp_data_file(relative = "data/tmp_imported_file_test.yml", contents = "one\n")
    absolute = Rails.root.join(relative)
    File.write(absolute, contents)
    yield relative, absolute
  ensure
    File.delete(absolute) if absolute && File.exist?(absolute)
  end

  test "digest returns an md5 of the file contents and nil for missing files" do
    with_temp_data_file do |relative, absolute|
      assert_equal Digest::MD5.file(absolute).hexdigest, ImportedFile.digest(relative)
    end

    assert_nil ImportedFile.digest("data/does_not_exist.yml")
  end

  test "relative_path normalizes absolute and relative paths" do
    assert_equal "data/speakers.yml", ImportedFile.relative_path("data/speakers.yml")
    assert_equal "data/speakers.yml", ImportedFile.relative_path(Rails.root.join("data/speakers.yml").to_s)
  end

  test "a path with no import record counts as changed" do
    with_temp_data_file do |relative, _absolute|
      assert ImportedFile.changed?(relative), "expected an unseen file to be changed"
    end
  end

  test "record! stores the fingerprint so the file is no longer changed" do
    with_temp_data_file do |relative, _absolute|
      ImportedFile.record!(relative)

      assert_not ImportedFile.changed?(relative)
      assert_equal 1, ImportedFile.where(file_path: relative).count
    end
  end

  test "record! upserts instead of duplicating on repeated calls" do
    with_temp_data_file do |relative, absolute|
      ImportedFile.record!(relative)

      File.write(absolute, "two\n")
      ImportedFile.record!(relative)

      assert_equal 1, ImportedFile.where(file_path: relative).count
      assert_not ImportedFile.changed?(relative)
    end
  end

  test "changed? is true again after the file contents change" do
    with_temp_data_file do |relative, absolute|
      ImportedFile.record!(relative)
      File.write(absolute, "different\n")

      assert ImportedFile.changed?(relative)
    end
  end

  test "forget! removes the import record" do
    with_temp_data_file do |relative, _absolute|
      ImportedFile.record!(relative)
      ImportedFile.forget!(relative)

      assert_equal 0, ImportedFile.where(file_path: relative).count
    end
  end

  test "record! is a no-op for a missing file" do
    assert_no_difference -> { ImportedFile.count } do
      ImportedFile.record!("data/does_not_exist.yml")
    end
  end
end
