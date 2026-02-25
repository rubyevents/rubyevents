require "test_helper"

class Talks::SlidesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @talk = talks(:one)
  end

  test "should get show" do
    get talk_slides_path(@talk), headers: {"Turbo-Frame" => "true"}
    assert_response :ok
    assert_template "talks/slides/show"
  end
end
