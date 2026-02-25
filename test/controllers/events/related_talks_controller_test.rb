require "test_helper"

class Events::RelatedTalksControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    @event = events(:rails_world_2023)
    @talks = @event.talks
    @talk = @talks.first
    get event_related_talks_path(@event, active_talk: @talk.slug)
    assert_response :success
    assert_equal @event, assigns(:event)
    assert_equal @event.talks, assigns(:talks)
    assert_equal @talk, assigns(:active_talk)
  end
end
