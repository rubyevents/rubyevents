class Events::InvolvementsController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[index]

  def index
    @event = Event.includes(:event_involvements).find_by(slug: params[:event_slug])
    return redirect_to(root_path, status: :moved_permanently) unless @event

    set_meta_tags(@event)
    involvements = @event.event_involvements.includes(:involvementable).order(:position).to_a
    @involvements_by_role = involvements.group_by(&:role)
    @participation = Current.user&.participation_for(@event)
  end
end
