require "test_helper"

class ContributionsControllerTest < ActionDispatch::IntegrationTest
  ContributionsController::STEPS.each do |step|
    test "should get #{step} as a turbo frame request" do
      get contribution_path(step), headers: {"Turbo-Frame" => step.to_s}

      assert_response :success
    end
  end
end
