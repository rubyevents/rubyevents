class Events::EventsController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[index]
  before_action :set_event, only: %i[index]

  def index
    @talks = @event.talks_in_running_order.where(meta_talk: true).includes(:speakers, :parent_talk, child_talks: :speakers).reverse
  end

  private

  def set_event
    @event = Event.includes(:organisation, talks: :speakers).find_by(slug: params[:event_slug])
  end
end
