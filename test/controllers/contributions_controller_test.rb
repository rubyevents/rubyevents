require "test_helper"

class ContributionsControllerTest < ActionDispatch::IntegrationTest
  test "index returns success" do
    get contributions_path
    assert_response :success
  end

  ContributionsController::STEPS.each do |step|
    test "should get #{step} as a turbo frame request" do
      get contribution_path(step), headers: {"Turbo-Frame" => step.to_s}

      assert_response :success
    end
  end

  test "talks_without_slides links the title to the talk page and the speaker to SpeakerDeck" do
    talk = talks(:one)
    speaker = users(:yaroslav)
    speaker.update_columns(speakerdeck: "yshmarov", talks_count: 1)
    talk.update_columns(slides_url: nil)

    get contribution_path(:talks_without_slides), headers: {"Turbo-Frame" => "talks_without_slides"}

    assert_response :success
    assert_select "##{ActionView::RecordIdentifier.dom_id(talk)}" do
      assert_select "a[href='#{talk_path(talk)}'][data-turbo-frame='_top']", text: talk.title
      assert_select "a[href='https://speakerdeck.com/yshmarov']", text: speaker.name
    end
    assert_select "#talks_without_slides a##{ActionView::RecordIdentifier.dom_id(talk)}", count: 0
  end
end
