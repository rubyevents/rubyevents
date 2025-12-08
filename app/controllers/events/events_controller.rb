class Events::EventsController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[index show]
  before_action :set_event, only: %i[index]

  def index
    @talks = @event.talks_in_running_order.where(meta_talk: true).includes(:speakers, :parent_talk, child_talks: :speakers).reverse
  end

  def show
    @talk = Talk.find_by(slug: params[:id])
  end

  private

  def set_event
    @event = Event.includes(:series, talks: :speakers).find_by(slug: params[:event_slug])
    set_meta_tags(@event)
  end
end
