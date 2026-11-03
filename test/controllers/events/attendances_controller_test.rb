require "test_helper"

class Events::AttendancesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:zero_talks)
    @talk = talks(:one)
    @event = @talk.event
    Event.reset_counters(@event.id, :talks)
    EventParticipation.create!(user: @user, event: @event, role: :attendee)
    sign_in_as @user
  end

  test "should show the full talk title in a keyboard-accessible tooltip" do
    get attendance_url(event_slug: @event.slug)

    assert_response :success
    assert_select "##{dom_id(@talk, :attendance)}" do
      assert_select "[data-controller='tooltip'][data-tooltip-content-value=?][tabindex='0']", @talk.title, text: @talk.title
    end
  end
end
