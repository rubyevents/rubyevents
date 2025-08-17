require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "can create a user with just a name" do
    user = User.create!(name: "John Doe")
    assert_equal "john-doe", user.slug
  end

  test "the slug provided is used" do
    user = User.create!(name: "John Doe", slug: "john-doe-2")
    assert_equal "john-doe-2", user.slug
  end

  test "should normalize github_handle by stripping URL, www, and @" do
    user = users(:one)

    user.github_handle = "Https://www.github.com/tekin"
    user.save
    assert_equal "tekin", user.github_handle

    user.github_handle = "github.com/tekin"
    user.save
    assert_equal "tekin", user.github_handle

    user.github_handle = "@tekin"
    user.save
    assert_equal "tekin", user.github_handle
  end
end
