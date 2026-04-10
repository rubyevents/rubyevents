class Profiles::InvolvementsController < ApplicationController
  include ProfileData

  def index
    event_involvements = @user.event_involvements.includes(:event)
    @involvements_by_role = event_involvements.group_by(&:role)
      .each do |role, involvements|
        involvements.map!(&:event)
          .sort_by!(&:sort_date)
          .reverse!
      end
  end
end
