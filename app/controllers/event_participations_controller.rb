class EventParticipationsController < ApplicationController
  include EventData

  before_action :set_event
  before_action :set_participation, only: [:destroy]
  before_action :set_favorite_users
  before_action :set_participants

  # POST /events/:event_slug/event_participations
  def create
    @participation = Current.user.event_participations.find_or_initialize_by(event: @event)
    @participation.role = participation_role unless @participation.speaker?

    if @participation.save
      set_participants
      respond_to do |format|
        format.html { redirect_to event_path(@event), notice: "Participation recorded!" }
        format.turbo_stream
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace_all(".participation_button", partial: "events/participation_button", locals: {event: @event, participation: nil, errors: @participation.errors}) }
        format.html { redirect_to event_path(@event), alert: "Failed to record participation." }
      end
    end
  end

  # DELETE /events/:event_slug/event_participations/:id
  def destroy
    return redirect_to event_path(@event), alert: "Participation not found." unless @participation

    @participation.destroy
    @participation = nil
    set_participants

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to event_path(@event), notice: "Participation removed." }
    end
  end

  private

  def participation_role
    allowed_roles = @event.upcoming? ? %w[attendee interested] : %w[attendee]
    params[:role].presence_in(allowed_roles)
  end
end
