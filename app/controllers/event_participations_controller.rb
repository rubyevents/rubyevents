class EventParticipationsController < ApplicationController
  before_action :set_event
  before_action :set_participation, only: [:destroy]

  # POST /events/:event_slug/event_participations
  def create
    @participation = @event.event_participations.build(participation_params)
    @participation.user = Current.user

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
    @participation.destroy
    @participation = Current.user&.main_participation_to(@event)
    set_participants

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to event_path(@event), notice: "Participation removed." }
    end
  end

  private

  def set_event
    @event = Event.find_by(slug: params[:event_slug])
    redirect_to root_path, status: :moved_permanently unless @event
  end

  def set_participation
    @participation = @event.event_participations.find_by(id: params[:id], user: Current.user)
    redirect_to event_path(@event), alert: "Participation not found." unless @participation
  end

  def set_participants
    @participants = @event.participants.preloaded.order(:name)
  end

  def participation_params
    params.permit(:attended_as)
  end
end
