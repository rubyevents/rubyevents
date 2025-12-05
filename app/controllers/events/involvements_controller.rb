class Events::InvolvementsController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[index]

  def index
    @event = Event.includes(:event_involvements).find_by(slug: params[:event_slug])
    involvements = @event.event_involvements.includes(:involvementable).order(:position).to_a
    @involvements_by_role = involvements.group_by(&:role)
    @participation = Current.user&.main_participation_to(@event)
  end
end
