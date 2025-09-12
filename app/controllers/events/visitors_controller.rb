class Events::VisitorsController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[index]

  def index
    @event = Event.includes(:event_participations).find_by(slug: params[:event_slug])
    @visitors = @event.visitor_participants.includes(:connected_accounts)
    @participation = Current.user&.main_participation_to(@event)
  end
end
