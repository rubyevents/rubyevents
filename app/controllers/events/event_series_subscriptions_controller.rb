class Events::EventSeriesSubscriptionsController < ApplicationController
  before_action :set_event_series

  # POST /events/series/:series_slug/event_series_subscriptions
  def create
    @subscription = @event_series.event_series_subscriptions.build(user: Current.user)

    if @subscription.save
      respond_to do |format|
        format.html { redirect_to series_path(@event_series), notice: "You are now following #{@event_series.name}." }
        format.turbo_stream
      end
    else
      respond_to do |format|
        format.html { redirect_to series_path(@event_series), alert: "Failed to follow series." }
        format.turbo_stream
      end
    end
  end

  # DELETE /events/series/:series_slug/event_series_subscriptions/:id
  def destroy
    @subscription = Current.user.event_series_subscriptions.find_by(id: params[:id])
    @subscription&.destroy

    respond_to do |format|
      format.html { redirect_to series_path(@event_series), notice: "You are no longer following #{@event_series.name}." }
      format.turbo_stream
    end
  end

  private

  def set_event_series
    @event_series = EventSeries.find_by(slug: params[:series_slug])
    @event_series ||= EventSeries.find_by_slug_or_alias(params[:series_slug])

    redirect_to root_path, alert: "Event series not found." unless @event_series
  end
end
