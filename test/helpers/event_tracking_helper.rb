# frozen_string_literal: true

module EventTrackingHelper
  def with_event_tracking
    Ahoy.track_bots = true
    yield
  ensure
    Ahoy.track_bots = false
  end
end
