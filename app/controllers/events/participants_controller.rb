class Events::ParticipantsController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[index]

  def index
    @event = Event.includes(:event_participations).find_by(slug: params[:event_slug])
    @participants = @event.participants.includes(:connected_accounts).order(:name)
    @participation = Current.user&.main_participation_to(@event)
  end
end
