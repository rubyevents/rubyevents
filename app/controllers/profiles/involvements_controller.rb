class Profiles::InvolvementsController < ApplicationController
  include ProfileData

  def index
    @involved_events = @user.involved_events.includes(:series).distinct.order(start_date: :desc)
    event_involvements = @user.event_involvements.includes(:event).where(event: @involved_events)
    involvement_lookup = event_involvements.group_by(&:event_id)

    @involvements_by_role = {}
    @involved_events.each do |event|
      involvements = involvement_lookup[event.id] || []
      involvements.each do |involvement|
        @involvements_by_role[involvement.role] ||= []
        @involvements_by_role[involvement.role] << event
      end
    end
  end
end
