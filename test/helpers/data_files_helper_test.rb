require "test_helper"

class DataFilesHelperTest < ActionView::TestCase
  test "github_edit_url links to the file on the main branch" do
    event = Static::Event.find_by_slug("railsconf-2024")

    assert_equal "https://github.com/rubyevents/rubyevents/edit/main/data/railsconf/railsconf-2024/event.yml", github_edit_url(event.project_file_path)
  end
end
