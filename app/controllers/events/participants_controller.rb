class Events::ParticipantsController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[index]
  before_action :set_event

  def index
    @participants = @event.participants.preloaded.order(:name).distinct
    @participation = Current.user&.main_participation_to(@event)
  end

  private

  def set_event
    @event = Event.includes(:event_participations).find_by(slug: params[:event_slug])
    redirect_to root_path, status: :moved_permanently unless @event
  end
end
