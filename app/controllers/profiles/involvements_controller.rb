class Profiles::InvolvementsController < ApplicationController
  include ProfileData

  def index
    event_involvements = @user.event_involvements.includes(:event, event_series: :events)
    @involvements_by_role = event_involvements.group_by(&:role).transform_values do |involvements|
      series, events = involvements.map(&:owner).compact.uniq.partition { |owner| owner.is_a?(EventSeries) }

      {series: series.sort_by(&:name), events: events.sort_by(&:sort_date).reverse}
    end
  end
end
