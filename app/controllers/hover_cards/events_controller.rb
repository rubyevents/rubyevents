# frozen_string_literal: true

class HoverCards::EventsController < ApplicationController
  skip_before_action :authenticate_user!

  def show
    @event = Event.find_by_slug_or_alias(params[:slug])

    if @event.blank?
      head :not_found
      return
    end

    return redirect_to event_path(@event) unless turbo_frame_request?

    render layout: false
  end
end
